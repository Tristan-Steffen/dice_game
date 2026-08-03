class_name GameRun
extends RefCounted
## Persistenter Zustand eines Spiellaufs: Geld, Würfel-Pool, Charms, Gravuren,
## Rundenfortschritt. Reine Daten + Ökonomie, keine Nodes; UI mutiert den
## Zustand nur über die Methoden hier und hört auf die Signale.

signal money_changed(money: int)
signal charms_changed
signal engravings_changed
signal packs_changed
signal combo_upgraded(combo_key: String, new_level: int)
signal side_bets_changed
signal hub_level_changed(level: int)
signal deals_changed
## Ein Pool-Würfel hat seinen Inhalt geändert (Kauf, Paket, Gravur, Nehmen-
## Effekt, Testmodus). EINZIGER Auffrischungs-Weg der Würfel-Anzeigen: die Trays,
## die Grubenwürfel und die Gravur-Station hängen alle hier - Instanzen werden
## NIE getauscht (become), also reicht ein Signal ohne Index.
signal pool_changed
signal pending_dice_changed
signal charge_changed(value: int)
signal secret_shop_discovered
signal secret_stock_changed

const POOL_SIZE := 30
## Charm-Plätze am Tisch (CharmRowView.SPOT_COUNT liest hier) - zugleich die harte
## Obergrenze: bei sechs Charms nimmt der Dock keinen weiteren an.
const CHARM_CAPACITY := 6
const BASE_GOAL := 150
## Zuwachs je Runde im ERSTEN Block; er verdoppelt sich mit jedem weiteren.
const GOAL_INCREMENT := 75
## Blocklänge der Ziel-Eskalation = die sechs am Hub gezeigten Stationen. Die
## Wertung wächst multiplikativ (Übertaktung, Gravuren, Charms) - ein konstanter
## Zuwachs würde daher von Block zu Block leichter.
const GOAL_BLOCK := 6

## Fahrplan-Marker der Stresstest-Station (goal_roadmap_markers) samt Anzeige-
## Texten - eine Quelle für Hub-Kopfzeile und Fahrplan-Hinweis.
const STRESS_MARKER := "stress"
const STRESS_NAME := "Stresstest"
const STRESS_HINT := "Stresstest-Konditionen: das Haus diktiert, unter welcher Auflage gespielt wird."

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
const SEED_CAPITAL_CHARGE := 1
const SEED_CAPITAL_II_CHARGE := 2
const DISCHARGE_CHARGE := 2
const INSURANCE_FRAUD_MONEY := 15
const SERVICE_FEE_MONEY := 3
const RIP_OFF_PER_DIE := 1
const GOLD_VEIN_MONEY := 10
const INTEREST_PER := 10
const STAGE_CAP_LIMIT := 2
const HIGH_VOLTAGE_STAGES := 3
const CALIBRATION_FACTOR := 0.5
const MAINS_HUM_FACTOR := 1.25
const FUSE_FAILURE_SCALE := 4.0
const SHOP_INFLATION_FACTOR := 1.25
const SHOP_DISCOUNT_FACTOR := 0.8
## Benchmark-Aufschläge je Malusklausel. Die Eichung (Bonus) zieht separat ab -
## der Aufschlag-Wächter darf sie nicht als "Benchmark schon gehoben" lesen.
const BENCHMARK_MALUS := {
	DealClause.BENCHMARK_SURCHARGE: 0.5,
	DealClause.BENCHMARK_SURCHARGE_II: 1.0,
	DealClause.BENCHMARK_SHOCK: 2.5,
	DealClause.USURY_CLAUSE: 4.0,
	DealClause.HIGH_EXPECTATIONS: 5.0,
}

## Überladung: das Rundenziel lässt sich bis zu OVERCHARGE_STAGES-mal füllen,
## jede Stufe fordert die doppelte Punktzahl der vorigen (150 / 300 / 600 / …).
## Der Punktestand ist kumulativ, Überschuss trägt automatisch weiter. Wie viele
## Stufen tatsächlich zählen, deckelt die Hub-Stufe (max_overcharge_stages).
const OVERCHARGE_STAGES := 5
## Supraleiter hebt den Deckel ganz auf; die Stufengrößen verdoppeln sich, ein
## großer Platzhalter begrenzt sich also von selbst.
const UNLIMITED_OVERCHARGE_STAGES := 99

## Ausbaustufen des Hubs (Casino-Lizenz): gegen Gold jederzeit im Shop bzw. am
## Hub kaufbar. Jede Stufe schaltet STRUKTUR frei (Shop-Plätze, Blättern,
## Nebenwetten, Rarität, Überladungs-Deckel) - Zahlen-Boni bleiben Sache der Charms.
## Zehn Stufen; die oberen sind bewusst teuer (Langzeit-Ziel eines Laufs).
const HUB_MAX_LEVEL := 10
## Preise für die Aufstiege 1→2 … 9→10 (steil steigend zum High Roller).
const HUB_UPGRADE_PRICES := [8, 12, 18, 25, 35, 55, 80, 120, 170]

## ZUSÄTZLICHE Gravur-Pakete je frisch erreichter Stufe - eine Datentabelle, das
## Stellen daran ist eine Zahlenänderung, kein Code. Das beseelte 3er-Würfel-
## Paket kommt bei JEDER Stufe ab 2 obendrauf und steht darum nicht hier drin;
## nicht gelistete Stufen bekommen nur dieses. "Kombination" ist das gemischte
## Paket - es zieht quer durch alle Sorten.
const HUB_REWARD_PACKS := {
	5: [Pack.TYPE_NUMBER, Pack.TYPE_MIXED],
	10: [Pack.TYPE_NUMBER, Pack.TYPE_NUMBER, Pack.TYPE_MIXED, Pack.TYPE_MIXED, Pack.TYPE_MIXED],
}
## Lizenz-Namen je Stufe (1-basiert), aufsteigende Casino-Prestige-Tiers.
const HUB_LEVEL_NAMES := ["Hinterzimmer", "Spielecke", "Lizenz", "Parkett", "Salon",
	"VIP-Lounge", "Suite", "Penthouse", "Privatclub", "High Roller"]
## Kurzbeschreibung, was der jeweilige AUFSTIEG (auf Stufe = Index+2) freischaltet.
const HUB_UPGRADE_UNLOCKS := [
	"Blättern + mehr Chips",    # → 2 Spielecke
	"Größerer Laden + Automat I",  # → 3 Lizenz
	"Nebenwetten",              # → 4 Parkett
	"Überladung ×4",            # → 5 Salon
	"Bessere Ware + Automat II",   # → 6 VIP-Lounge
	"Überladung ×5 + 3. Bündel",# → 7 Suite
	"Günstiges Blättern",       # → 8 Penthouse
	"Erlesene Ware + Automat III", # → 9 Privatclub
	"Legendäre Ware",           # → 10 High Roller
]

## Shop-Platzzahlen je Hub-Stufe (1-basiert). Der Laden wächst nicht sprunghaft,
## sondern füllt sich: Stufe 1 zeigt WENIGE, dafür große Angebote; höhere Stufen
## tauschen Kartengröße gegen Anzahl. "Chips" = Gravur- + Übertaktungs-Schale.
const SHOP_CHARM_SLOTS := [2, 2, 3, 3, 3, 4, 4, 4, 5, 5]
const SHOP_DICE_SLOTS  := [1, 1, 2, 2, 2, 2, 3, 3, 3, 3]
const SHOP_CHIP_SLOTS  := [2, 3, 5, 5, 6, 7, 8, 8, 9, 10]
const SHOP_PACK_SLOTS  := [1, 1, 2, 2, 2, 3, 3, 3, 4, 4]

## Schwellen der Struktur-Freischaltungen (1-basierte Hub-Stufe).
const HUB_FLIPPING_LEVEL := 2      # Shop-Blättern
const HUB_SIDE_BETS_LEVEL := 4     # Nebenwetten installiert
const HUB_RARITY_UNCOMMON_LEVEL := 6
const HUB_CHEAP_FLIP_LEVEL := 8    # halbierte Blätter-Gebühr
const HUB_RARITY_RARE_LEVEL := 9
const HUB_RARITY_LEGENDARY_LEVEL := 10

## Freischaltung der drei Fumble-Automaten (nacheinander): I ab Lizenz, II ab
## VIP-Lounge, III ab Privatclub.
const HUB_SLOT_LEVELS := [3, 6, 9]

var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

var round_number: int = 1
var round_goal: int = BASE_GOAL

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
## Übertaktungsrabatt: der nächste Charm im Laden ist gratis (verbraucht sich).
var free_charm_pending: bool = false
## Freispiele: Automaten, die ihren Gratisdreh dieser Runde schon hatten.
var free_spins_used: Array[int] = []

## Aktuelle Hub-Ausbaustufe (1..HUB_MAX_LEVEL). Steuert Shop-Umfang, Nebenwetten,
## Rarität und den Überladungs-Deckel (siehe die shop_*/hub_*-Abfragen unten).
var hub_level: int = 1

## Immer genau POOL_SIZE Einträge, jeder eine EIGENE DieDefinition-Instanz,
## damit eine Ätzung nie mehrere Würfel zugleich verändert.
var owned_pool: Array[DieDefinition] = []
var owned_charms: Array[Charm] = []
var owned_engravings: Array[Engraving] = []
## Versiegelte Pakete im Werkstatt-Lager; sie warten dort beliebig lange.
var owned_packs: Array[Pack] = []
## Die Pakete des JÜNGSTEN Hub-Ausbaus, in Gewähr-Reihenfolge - Vorlage der
## Reveal-Zeremonie. Gebucht sind sie längst (upgrade_hub); das hier ist nur die
## Merkliste, wovon die Zeremonie erzählt.
var last_hub_reward_packs: Array[Pack] = []
## Beim Händler hinterlegte Würfel: in der Chip-Schale gekauft, aber noch nicht
## eingetauscht. Sie liegen im Laden, bis der Spieler selbst bestimmt, welchen
## Pool-Platz sie übernehmen - der Automat sucht ihn sonst allein aus, und eine
## Essenz ist angeboren und nicht wiederbeschaffbar.
var pending_dice: Array[DieDefinition] = []
## Platzierte Nebenwetten der kommenden Runde; am Rundenende geprüft und geleert.
var active_side_bets: Array[SideBet] = []
## Testmodus: consume_engraving verbraucht nichts, Bord und Schubladen zeigen
## jeden Archetyp. Meldet sich als Bestandsänderung - sie bauen daran neu.
var unlimited_engravings: bool = false:
	set(value):
		if unlimited_engravings == value:
			return
		unlimited_engravings = value
		engravings_changed.emit()
## Übertaktungs-Stufen je Kombination (Key -> Stufe); jede Stufe addiert
## Basis-Mult und Basispunkte erneut (siehe DiceScoring/Systemkonsole).
var combo_levels: Dictionary = {}

# Zustand der Effektkatalog-Charms:
var farkle_count: int = 0  # Zerbrochener Spiegel
var lumpensammler_value: int = 0  # Glückszahl, je Runde neu (0 = kein Lumpensammler)
var gravierstift_used_this_round: bool = false
var old_penny_payouts: int = 0  # Glücksgroschen: wächst erst NACH jeder Auszahlung
## Rampenlicht: die hervorgehobene Kombination dieser Runde ("" = keine) und ob
## sie schon kassiert wurde - je Runde steigt höchstens EINE Stufe.
var spotlight_combo: String = ""
var spotlight_claimed_this_round: bool = false
## Goldener Handschlag: die Klausel vergoldet je Runde genau EINEN Würfel.
var golden_handshake_used_this_round: bool = false

## Speicher der Phosphoreszenz je Würfel-Exemplar (Instanz-id des DieDefinition):
## Basispunkte, und unter der Leuchtstoffröhre auch der Mult. Beide SAMMELN über
## den ganzen Run - sie sterben erst mit dem Run, nicht mit der Runde.
var essence_phosphor_store: Dictionary = {}
var essence_phosphor_mult: Dictionary = {}
## Verbrauchtes Löschgas je Würfel-Exemplar - eine Runden-Marke.
var essence_smother_used: Dictionary = {}
## Schon gekippte Irrlicht-Würfel dieser Runde.
var essence_tip_used: Dictionary = {}
## Schon abgeerntete Ethylen-Würfel dieser Runde.
var essence_harvest_used: Dictionary = {}
## Auslösungen und Krits der bisherigen Hände DIESER Runde - Dunkelkammer und
## Gewitterfront schleppen sie in die nächste Hand mit.
var round_trigger_count: int = 0
var round_crit_count: int = 0

## Sitzungszustand der Fumble-Automaten (überlebt Zoom/Runden, bis Fumble oder
## Auszahlung ihn zurücksetzt). Ökonomie läuft über spin_slot/redeem_slots.
var slot_bank := SlotMachine.new()

static func new_run() -> GameRun:
	var run := GameRun.new()
	for i in POOL_SIZE:
		run.owned_pool.append(DieDefinition.standard())
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
## Besitz-Slots - wer einen Charm ANZEIGEN will (Hologramm, Dock-Pad), muss
## hierüber umrechnen.
func charm_slots() -> Array[int]:
	var slots: Array[int] = []
	for entry in _resolved_charms():
		slots.append(int(entry["slot"]))
	return slots

## Wirkende Charms als {id, slot}: ein Totem übernimmt die WIRKUNG des Nachbarn,
## behält aber SEINEN Besitz-Slot - dort sitzt sein Hologramm.
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
	var factor := 1.0
	var boost := deal_bonus_factor()
	if _clause_active(DealClause.HAPPY_HOUR):
		factor *= 2.0 * boost
	if _clause_active(DealClause.ALL_ON_RED):
		factor *= 3.0 * boost
	return factor

# --- Hub-Ausbau ---------------------------------------------------------------

## Preis des nächsten Aufstiegs; 0, wenn die Maximalstufe erreicht ist.
func hub_upgrade_price() -> int:
	if hub_level >= HUB_MAX_LEVEL:
		return 0
	return HUB_UPGRADE_PRICES[hub_level - 1]

## Name der nächsten Stufe (leer bei Maximalstufe).
func hub_next_level_name() -> String:
	if hub_level >= HUB_MAX_LEVEL:
		return ""
	return HUB_LEVEL_NAMES[hub_level]

## Freischaltung des nächsten Aufstiegs als Kurztext (leer bei Maximalstufe).
func hub_next_unlock() -> String:
	if hub_level >= HUB_MAX_LEVEL:
		return ""
	return HUB_UPGRADE_UNLOCKS[hub_level - 1]

## Name der AKTUELLEN Stufe.
func hub_level_name() -> String:
	return HUB_LEVEL_NAMES[clampi(hub_level, 1, HUB_MAX_LEVEL) - 1]

func can_upgrade_hub() -> bool:
	return hub_level < HUB_MAX_LEVEL and money >= hub_upgrade_price()

## Kauft den nächsten Aufstieg: Preis abziehen, Stufe heben, Signal. No-op, wenn
## nicht bezahlbar oder bereits max.
func upgrade_hub() -> void:
	if not can_upgrade_hub():
		return
	add_money(-hub_upgrade_price())
	hub_level += 1
	_grant_hub_rewards(hub_level)
	hub_level_changed.emit(hub_level)

## Belohnung einer frisch erreichten Stufe: versiegelte Ware ins Lager. JEDE
## Stufe ab 2 bringt ein 3er-Würfel-Paket, dessen drei Auswahl-Würfel ALLE eine
## Seele tragen; HUB_REWARD_PACKS legt je Stufe noch Gravur-Pakete obendrauf.
## Geöffnet wird alles über den gewohnten Weg in der Werkstatt.
func _grant_hub_rewards(level: int) -> int:
	last_hub_reward_packs.clear()
	var granted := 0
	var template := _reward_dice_template()
	if not template.is_empty():
		var pack := Pack.dice_pack(template)
		pack.essence_guaranteed = true
		pack.description = "%d× %s aufgedeckt, alle beseelt - einer darf mit." \
			% [int(template["count"]), template["name"]]
		owned_packs.append(pack)
		last_hub_reward_packs.append(pack)
		granted += 1
	for pack_type: String in HUB_REWARD_PACKS.get(level, []):
		var extra := Pack.by_type(pack_type)
		owned_packs.append(extra)
		last_hub_reward_packs.append(extra)
		granted += 1
	if granted > 0:
		packs_changed.emit()
	return granted

## Vorlage des Belohnungs-Pakets: eine der 3er-Sorten, damit die Wahl echt ist.
func _reward_dice_template() -> Dictionary:
	var bundles: Array[Dictionary] = []
	for t: Dictionary in DiceOffer.TEMPLATES:
		if int(t["count"]) >= 3:
			bundles.append(t)
	return bundles.pick_random() if not bundles.is_empty() else {}

## --- Aus der Hub-Stufe abgeleitete Struktur-Freischaltungen -------------------
## Alles läuft über diese Abfragen, damit Aufrufer nie rohe Stufen vergleichen.

## Wirksame Zahl an Überladungs-Stufen: die Hub-Stufe setzt den Rahmen, Klauseln
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

## Rahmen der Hub-Stufe OHNE Klausel-Wirkungen: 3 (bis Salon), 4 (Salon/VIP),
## 5 (ab Suite).
func overcharge_frame() -> int:
	if hub_level >= 7:
		return 5
	if hub_level >= 5:
		return 4
	return 3

func side_bets_unlocked() -> bool:
	return hub_level >= HUB_SIDE_BETS_LEVEL

func shop_flipping_unlocked() -> bool:
	return hub_level >= HUB_FLIPPING_LEVEL

## Halbierte Blätter-Gebühr ab Penthouse (stapelt mit dem Wechselgeld-Charm).
func shop_flip_fee_factor() -> float:
	return 0.5 if hub_level >= HUB_CHEAP_FLIP_LEVEL else 1.0

## Raritäts-Stufe der Shop-Ware: 0 keine, 1 ungewöhnlich (VIP-Lounge), 2 selten
## (Privatclub), 3 legendär (High Roller). Steuert den garantierten Premium-Charm
## + die Gravur-Mindestrarität.
func shop_rarity_tier() -> int:
	if hub_level >= HUB_RARITY_LEGENDARY_LEVEL:
		return 3
	if hub_level >= HUB_RARITY_RARE_LEVEL:
		return 2
	if hub_level >= HUB_RARITY_UNCOMMON_LEVEL:
		return 1
	return 0

## Shop-Platzzahlen je Hub-Stufe (siehe SHOP_*_SLOTS): wenige, große Angebote am
## Anfang; mehr, kleinere später. Rarität kommt zusätzlich obendrauf (shop_rarity_tier).
func _slot_at(ladder: Array, default_top: int) -> int:
	var idx := clampi(hub_level, 1, HUB_MAX_LEVEL) - 1
	return ladder[idx] if idx < ladder.size() else default_top

func shop_charm_slots() -> int:
	return _slot_at(SHOP_CHARM_SLOTS, 5)

func shop_dice_slots() -> int:
	return _slot_at(SHOP_DICE_SLOTS, 3)

## Gesamtbudget der Chip-Schale; ein Drittel davon sind Übertaktungen (1..3).
func shop_chip_slots() -> int:
	return _slot_at(SHOP_CHIP_SLOTS, 10)

func shop_overclock_slots() -> int:
	return clampi(shop_chip_slots() / 3, 1, 3)

## Gravur-Pakete im Regal. Deutlich weniger Plätze als früher Einzel-Gravuren -
## ein Paket ersetzt drei bis vier davon.
func shop_pack_slots() -> int:
	return _slot_at(SHOP_PACK_SLOTS, 4)

func purchase_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	_replace_pool_entry(def)

## Kauf aus der Chip-Schale: bezahlt, aber NICHT eingesetzt - der Würfel bleibt
## beim Händler liegen, bis der Spieler selbst den Platz wählt. Hinterlegt wird
## eine eigene Instanz, denn die Auslage hält das Original weiter (Referenz-Regel).
func stash_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	pending_dice.append(def.instantiate())
	pending_dice_changed.emit()

## Bestandener Stresstest: EIN versiegeltes Würfel-Paket mit Seelengarantie ins
## Lager. Ausgewürfelt wird der Würfel erst beim Öffnen in der Werkstatt - wie
## bei jedem Paket.
func grant_stress_reward() -> Pack:
	var templates := DiceOffer.pick_templates(1, charm_ids())
	if templates.is_empty():
		return null
	var pack := Pack.stress_die(templates[0])
	owned_packs.append(pack)
	packs_changed.emit()
	return pack

## Löst einen hinterlegten Würfel gegen einen Pool-Platz ein. Der Pool-Eintrag
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

func purchase_dice(defs: Array[DieDefinition], price: int) -> void:
	add_money(-price)
	for def in defs:
		_replace_pool_entry(def)

## Überschreibt einen zufälligen Pool-Eintrag (bevorzugt "normal", damit frühere
## Käufe nicht verdrängt werden) mit dem Inhalt von def. Der Eintrag wird IN
## SEINER Instanz überschrieben (become), nie getauscht: Rundendeck, Trays und
## Raster halten dieselbe Referenz und zeigen den neuen Würfel dadurch sofort.
## EINZIGE Stelle, an der ein Kauf einen Pool-Platz übernimmt (Würfelkauf, Paket,
## Automaten-Würfel). Vorrang hat ein normaler Würfel OHNE Seele: eine Essenz ist
## angeboren und nicht wiederbeschaffbar - sie wird erst übermalt, wenn kein
## seelenloser Platz mehr frei ist.
func _replace_pool_entry(def: DieDefinition) -> DieDefinition:
	var normal_indices: Array[int] = []
	var soulless_indices: Array[int] = []
	for i in owned_pool.size():
		if owned_pool[i].style_id == "normal":
			normal_indices.append(i)
			if owned_pool[i].essence_id == "":
				soulless_indices.append(i)

	var target_index: int
	if not soulless_indices.is_empty():
		target_index = soulless_indices[randi() % soulless_indices.size()]
	elif not normal_indices.is_empty():
		target_index = normal_indices[randi() % normal_indices.size()]
	else:
		target_index = randi() % owned_pool.size()
	var target := owned_pool[target_index]
	target.become(def)
	pool_changed.emit()
	return target

## Kauft einen Charm - der Preis wird nur fällig, wenn der Dock ihn auch aufnimmt.
func purchase_charm(charm: Charm, price: int) -> bool:
	if charms_full():
		return false
	add_money(-price)
	return _grant_charm(charm)

## Harte Obergrenze der Charm-Plätze (= CharmRowView.SPOT_COUNT): ist der Dock
## voll, gibt es KEINE Warteschlange - ein weiterer Charm ist nicht kaufbar.
func charms_full() -> bool:
	return owned_charms.size() >= CHARM_CAPACITY

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
	return CharmEffects.charm_sell_value(owned_charms[index].sell_value, charm_ids())

## Verkauft den Charm auf Platz index: entfernt ihn, Erlös aufs Konto.
func sell_charm(index: int) -> void:
	if index < 0 or index >= owned_charms.size():
		return
	var value := charm_sell_value(index)
	owned_charms.remove_at(index)
	add_money(value)
	charms_changed.emit()

## Kauft eine einzelne Gravur (Shop): Preis abziehen, sofort ins Inventar.
func purchase_engraving(engraving: Engraving, price: int) -> void:
	add_money(-price)
	grant_engraving(engraving)

func grant_engraving(engraving: Engraving) -> void:
	owned_engravings.append(engraving)
	engravings_changed.emit()

# --- Pakete (Kauf im Laden, Öffnen in der Werkstatt) --------------------------

func purchase_pack(pack: Pack, price: int) -> void:
	add_money(-price)
	grant_pack(pack)

## Legt ein Paket ohne Zahlung ins Lager (Wett-Gewinn).
func grant_pack(pack: Pack) -> void:
	owned_packs.append(pack)
	packs_changed.emit()

## Mindest-Seltenheit im Paketinhalt; steigt mit der Raritäts-Stufe des Hubs.
func pack_engraving_floor() -> Engraving.Rarity:
	match shop_rarity_tier():
		0:
			return Engraving.Rarity.COMMON
		1:
			return Engraving.Rarity.UNCOMMON
	return Engraving.Rarity.RARE

## Öffnet das Paket auf Platz index - der Inhalt wird ERST JETZT ausgewürfelt,
## aber NOCH NICHT verbucht: die Entsiegelungs-Zeremonie darf die Seltenheit
## anteasern, ohne dass die Schubladen-Zähler sie vorab verraten. Gravuren bucht
## erst stash_engravings, Würfel place_pack_die.
func open_pack(index: int) -> Dictionary:
	var empty := {"engravings": [] as Array[Engraving], "dice": [] as Array[DieDefinition]}
	if index < 0 or index >= owned_packs.size():
		return empty
	var pack := owned_packs[index]
	owned_packs.remove_at(index)
	var result := empty
	if pack.is_dice_pack():
		result["dice"] = pack.roll_dice(charm_ids(), owned_essence_ids(), hub_level)
	else:
		# Das Paket bringt seine eigene Untergrenze mit (Automaten-Stufe); es gilt
		# die höhere von beiden.
		var floor_rarity := maxi(pack.rarity_floor, pack_engraving_floor()) as Engraving.Rarity
		result["engravings"] = pack.roll_engravings(floor_rarity)
	packs_changed.emit()
	return result

## Verbucht ausgewürfelten Paket-Inhalt in die Vorräte (Zeremonie-Abschluss).
func stash_engravings(engravings: Array[Engraving]) -> void:
	if engravings.is_empty():
		return
	for engraving in engravings:
		owned_engravings.append(engraving)
	engravings_changed.emit()

## Setzt einen Paket-Würfel auf einen SELBST gewählten Pool-Platz; der bisherige
## Würfel dort verfällt. Abgelehnte Würfel laufen hier nie ein.
func place_pack_die(def: DieDefinition, pool_index: int) -> void:
	if def == null or pool_index < 0 or pool_index >= owned_pool.size():
		return
	# In den bestehenden Würfel hinein, nicht an seine Stelle: das Rundendeck und
	# die Trays halten dieselbe Instanz und zeigen den Tausch dadurch sofort.
	var target := owned_pool[pool_index]
	target.become(def)
	pool_changed.emit()

# --- Übertakten (Systemkonsole): Kombinationen ohne Stufen-Limit aufwerten ----

## Aktuelle Übertaktungs-Stufe einer Kombination.
func combo_level(combo_key: String) -> int:
	return int(combo_levels.get(combo_key, 0))

## Preis der Stufe level+1: Basis folgt der Kombinationsstärke (Basis-Mult),
## jede weitere Stufe desselben Chips kostet die Basis erneut obendrauf -
## kein Stufen-Limit, die Preiskurve ist die einzige Bremse.
static func overclock_price_at(combo_key: String, level: int) -> int:
	return (4 + DiceScoring.mult_for(combo_key)) * (level + 1)

## Preis der nächsten Stufe dieser Kombination (Ladenpreis-Klauseln eingerechnet).
func overclock_price(combo_key: String) -> int:
	return shop_price(overclock_price_at(combo_key, combo_level(combo_key)))

func can_overclock(combo_key: String) -> bool:
	return money >= overclock_price(combo_key)

## Kauft die nächste Stufe: Preis abziehen, Stufe heben (hebt Basispunkte und
## Multiplikator der Kombination, siehe DiceScoring).
func overclock_combo(combo_key: String) -> void:
	add_money(-overclock_price(combo_key))
	grant_combo_level(combo_key)

## Hebt eine Kombination ohne Zahlung eine Stufe (Wett-Gewinn) - dieselbe
## Buchung wie ein Kauf, damit die Zeremonie am Signal hängt.
func grant_combo_level(combo_key: String) -> void:
	if combo_key == "":
		return
	combo_levels[combo_key] = combo_level(combo_key) + 1
	combo_upgraded.emit(combo_key, combo_levels[combo_key])

## Rundenbeginn: Runden-Marken zurücksetzen, Lumpensammler würfelt seine
## Glückszahl neu - je Vorkommen einmal. Auch Drossel und Rampenlicht werden hier
## gesetzt; die Klauseln der Runde stehen zu diesem Zeitpunkt schon
## (unterschrieben wird VOR dem Rundenstart).
func apply_round_start_charms() -> void:
	gravierstift_used_this_round = false
	roll_essence_round_state()
	var ids := charm_ids()
	if ids.has(Charm.RAG_COLLECTOR):
		_roll_lumpensammler_value()
	throttled_combos = _round_throttled_combos()
	spotlight_claimed_this_round = false
	golden_handshake_used_this_round = false
	# Rampenlicht per Charm ODER Klausel - nie auf einem gedrosselten Chip
	# (der wertet nicht, das Licht wäre verschenkt).
	if CharmEffects.has_spotlight(ids) or _clause_active(DealClause.SPOTLIGHT) \
			or _clause_active(DealClause.POWER_SPIKE):
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

## Die heißesten Chips zuerst: höchste Übertaktungs-Stufe, bei Gleichstand der
## ranghöhere (HAND_PRIORITY). Deterministisch, damit der Spieler im Shop davor
## planen kann. "Höchste Zahl" ist die Rückfall-Kategorie jeder Hand und bleibt
## darum immer wertbar - sie wird nie gedrosselt.
func hottest_combos(count: int) -> Array[String]:
	var keys: Array[String] = []
	for key: String in DiceScoring.HAND_PRIORITY:
		if key != DiceScoring.ONE_KIND:
			keys.append(key)
	# Gleichstand ausdrücklich über den Rang brechen: sort_custom sortiert nicht
	# stabil, die Reihenfolge aus HAND_PRIORITY allein trägt also nicht.
	keys.sort_custom(func(a: String, b: String) -> bool:
		if combo_level(a) != combo_level(b):
			return combo_level(a) > combo_level(b)
		return DiceScoring.HAND_PRIORITY.find(a) < DiceScoring.HAND_PRIORITY.find(b))
	return keys.slice(0, maxi(0, count))

## Der heißeste Chip ("" = keiner) - Kurzform von hottest_combos.
func hottest_combo() -> String:
	var hottest := hottest_combos(1)
	return "" if hottest.is_empty() else hottest[0]

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
	if _clause_active(DealClause.ALL_ROUNDER) and not throttled_combos.has(combo_key):
		throttled_combos.append(combo_key)
	if _clause_active(DealClause.STANDARD_PROTOCOL):
		for key: String in DiceScoring.HAND_PRIORITY:
			if key != combo_key and not throttled_combos.has(key):
				throttled_combos.append(key)
	return throttled_combos.size() > before

## Hitzestau: die gespielte Kombination verliert eine Übertaktungs-Stufe, nie
## unter die ungestufte Grundform. true = es ging tatsächlich eine runter.
func apply_heat_buildup(combo_key: String) -> bool:
	if not _clause_active(DealClause.HEAT_BUILDUP):
		return false
	var level := combo_level(combo_key)
	if level <= 0:
		return false
	combo_levels[combo_key] = level - 1
	combo_upgraded.emit(combo_key, level - 1)
	return true

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
## Risiko- und Knebelvertrag. Mit TREAT_CHANCE wird EIN Platz stattdessen ein
## Werbegeschenk (reiner Bonus); welcher, verteilt TREAT_TIER_WEIGHTS - meist der
## Standard-, selten der Knebelplatz. In der Stresstest-Runde liegen stattdessen
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
		var tier: DealClause.Tier = DealClause.Tier.TREAT if i == treat_slot else tiers[i]
		route_offers.append(_draw_card(tier))

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

## Drei der sechs Stresstest-Konditionen, ohne einen zweiten Benchmark-Aufschlag.
func _roll_boss_offers() -> void:
	var pool: Array[String] = []
	for clause_id in DealClause.ids_for(DealClause.Tier.BOSS, DealClause.Kind.MALUS):
		if not _benchmark_blocked(clause_id):
			pool.append(clause_id)
	pool.shuffle()
	for i in mini(ROUTE_OFFER_COUNT, pool.size()):
		route_offers.append({CARD_TIER: DealClause.Tier.BOSS, CARD_BONUS: "", CARD_MALUS: pool[i]})

## Baut eine Vertragskarte: erst das Kleingedruckte, dann der Bonus - dessen Topf
## muss die Tags des Malus meiden (sonst entstehen Nullsummen-Paare).
func _draw_card(tier: DealClause.Tier) -> Dictionary:
	var malus_id := ""
	if tier != DealClause.Tier.TREAT:
		malus_id = _draw_clause(tier, DealClause.Kind.MALUS, [] as Array[String])
	var bonus_id := _draw_clause(tier, DealClause.Kind.BONUS, DealClause.tags_of(malus_id))
	return {CARD_TIER: tier, CARD_BONUS: bonus_id, CARD_MALUS: malus_id}

## Zieht eine Klausel des Topfes: nie eine, die schon in der Auslage liegt oder in
## diesem Block unterschrieben wurde, nie eine mit einem verbotenen Tag, nie einen
## ZWEITEN Benchmark-Malus (sonst baut sich der Spieler ein unerreichbares Ziel).
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
		if _shares_tag(clause_id, taboo_tags) or _benchmark_blocked(clause_id):
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

## Ob die Klausel als zweiter Benchmark-Aufschlag ausgeschlossen ist.
func _benchmark_blocked(clause_id: String) -> bool:
	return BENCHMARK_MALUS.has(clause_id) and _benchmark_already_raised()

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
	match clause_id:
		DealClause.ADVANCE_PAYMENT:
			add_money(ADVANCE_PAYMENT_MONEY * boost)
		DealClause.BLANK_CHEQUE:
			add_money(BLANK_CHEQUE_MONEY * boost)
		DealClause.SEED_CAPITAL, DealClause.SEED_CAPITAL_II:
			add_charge(instant_clause_charge(clause_id, boost))
		DealClause.DISCHARGE:
			spend_charge(DISCHARGE_CHARGE)
		DealClause.OVERCLOCK_DISCOUNT:
			free_charm_pending = true
		DealClause.FREE_SPINS:
			free_spins_used.clear()

## Ladung, die diese Klausel mit der Unterschrift prägt (0 = keine). Eine Quelle
## für Buchung und Zeremonie: scene_root schickt je ⚡ einen Kometen zur Bank.
static func instant_clause_charge(clause_id: String, bonus_factor: int = 1) -> int:
	match clause_id:
		DealClause.SEED_CAPITAL:
			return SEED_CAPITAL_CHARGE * bonus_factor
		DealClause.SEED_CAPITAL_II:
			return SEED_CAPITAL_II_CHARGE * bonus_factor
	return 0

## Abrechnung: der Stresstest ist überstanden, alle Klauseln des Blocks verfallen.
func settle_block_deals() -> void:
	if active_deals.is_empty():
		return
	active_deals.clear()
	free_charm_pending = false
	free_spins_used.clear()
	deals_changed.emit()

## Ob die Klausel in diesem Block schon unterschrieben wurde (auch wenn ihre
## Wirkung längst abgelaufen ist) - sie wird dann nicht erneut angeboten.
func _taken_this_block(clause_id: String) -> bool:
	for entry in active_deals:
		if entry["id"] == clause_id:
			return true
	return false

func _benchmark_already_raised() -> bool:
	for clause_id: String in BENCHMARK_MALUS:
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

## Tatsächliches Rundenziel: das GESETZTE Grundziel × aller wirkenden Benchmark-
## Klauseln. Bewusst über round_goal statt goal_for_round - wer das Ziel direkt
## setzt (Test, Debug), muss den Balken auch verschieben können.
func effective_goal() -> int:
	return roundi(round_goal * _benchmark_factor(round_number))

## Wie effective_goal, aber für eine beliebige Runde des Fahrplans - so zeigt die
## Station der laufenden Runde sofort, was ein Benchmark-Malus sie kostet.
func effective_goal_for_round(n: int) -> int:
	return roundi(goal_for_round(n) * _benchmark_factor(n))

## Faktor der in Runde n wirkenden Benchmark-Klauseln: Aufschläge multiplizieren
## sich, die Eichung halbiert.
func _benchmark_factor(n: int) -> float:
	var factor := 1.0
	for entry in active_deals:
		var clause := DealClause.find(entry["id"])
		if clause == null or not _scope_reaches(entry, clause.scope, n):
			continue
		if BENCHMARK_MALUS.has(clause.id):
			factor *= 1.0 + float(BENCHMARK_MALUS[clause.id])
		elif clause.id == DealClause.CALIBRATION:
			# Nachlass: der Winkeladvokat wendet ihn ein zweites Mal an, statt die
			# Zahl zu verdoppeln - sonst hübe "−50%" auf "−100%" das Ziel ganz auf.
			factor *= pow(CALIBRATION_FACTOR, deal_bonus_factor())
	return factor

## Faktor auf die GESAMTE Rundenauszahlung (Bank + übrige Würfel). Happy Hour und
## Alles auf Rot stehen bewusst NICHT hier, sondern in money_gain_factor - sonst
## zahlte die Runde doppelt.
func round_payout_factor() -> float:
	var factor := 1.0
	if _clause_active(DealClause.DEDUCTION):
		factor *= 0.75
	if _clause_active(DealClause.HALF_PAYOUT):
		factor *= 0.5
	return factor

## Sparprämie: Aufschlag je übrigem Würfel (zusätzlich zum Sparschwein-Charm).
func deal_unused_die_bonus() -> int:
	return SAVINGS_DIE_BONUS * deal_bonus_factor() if _clause_active(DealClause.SAVINGS_BONUS) else 0

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

## Wartungs-Gravur: je genommener Hand eine Zahl-Gravur.
func grants_engraving_per_hand() -> bool:
	return _clause_active(DealClause.MAINTENANCE_ENGRAVING)

## Zinsen: Rundenende-Ertrag auf das gehaltene Guthaben.
func interest_income() -> int:
	return (money / INTEREST_PER) * deal_bonus_factor() if _clause_active(DealClause.INTEREST) else 0

## Goldader: Geld je geräumter Überladungs-Stufe (0 = die Klausel ruht).
func gold_vein_income() -> int:
	return GOLD_VEIN_MONEY * deal_bonus_factor() if _clause_active(DealClause.GOLD_VEIN) else 0

## Doppellader: wie viele Ladungen eine geräumte Überladungs-Stufe prägt.
func charge_per_stage() -> int:
	return 2 * deal_bonus_factor() if _clause_active(DealClause.DOUBLE_LOADER) else 1

## Ladenpreis-Faktor (Inflation ×1,25, Skonto ×0,8 - beide multiplikativ).
func shop_price_factor() -> float:
	var factor := 1.0
	if _clause_active(DealClause.INFLATION):
		factor *= SHOP_INFLATION_FACTOR
	if _clause_active(DealClause.CASH_DISCOUNT):
		# Nachlass wie die Eichung: zweimal angewandt statt verdoppelt.
		factor *= pow(SHOP_DISCOUNT_FACTOR, deal_bonus_factor())
	return factor

## Ladenpreis einer Ware; jeder Preisschild-Aufrufer geht hier durch.
func shop_price(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * shop_price_factor()))

## Übertaktungsrabatt: der nächste Charm im Laden ist gratis.
func charm_is_free() -> bool:
	return free_charm_pending and _clause_active(DealClause.OVERCLOCK_DISCOUNT)

func consume_free_charm() -> void:
	free_charm_pending = false

## Stromsperre: die Automaten bleiben diese Runde aus.
func slots_enabled() -> bool:
	return not _clause_active(DealClause.POWER_CUT)

## Freispiele: dieser Automat hat seinen Gratisdreh noch offen.
func slot_spin_is_free(machine: int) -> bool:
	return _clause_active(DealClause.FREE_SPINS) and not free_spins_used.has(machine)

## Quotenbonus/Turniernacht: Auszahlungsfaktor gewonnener Nebenwetten.
func side_bet_payout_factor() -> int:
	return 2 * deal_bonus_factor() if _clause_active(DealClause.ODDS_BONUS) \
		or _clause_active(DealClause.TOURNAMENT_NIGHT) else 1

## Wettsteuer: Einsätze kosten doppelt (Anzeige UND Abbuchung lesen das hier).
func side_bet_stake_factor() -> int:
	return 2 if _clause_active(DealClause.BETTING_TAX) else 1

## Fälliger Bar-Einsatz einer Wette.
func side_bet_stake(bet: SideBet) -> int:
	return bet.stake * side_bet_stake_factor()

## Fälliger Gravur-Einsatz einer Wette.
func side_bet_stake_engravings(bet: SideBet) -> int:
	return bet.stake_engravings * side_bet_stake_factor()

## Fälliger Ladungs-Einsatz einer Wette (⚡).
func side_bet_stake_charge(bet: SideBet) -> int:
	return bet.stake_charge * side_bet_stake_factor()

## Frankiermaschine: so viele Zahl-Gravuren schenkt sie am Rundenende - je eine
## pro Meteor der Rundenende-Zeremonie (scene_root treibt Flug und grant).
const STAMP_ENGRAVINGS := 3

## Würfelt EINE zufällige Zahl-Gravur der Frankiermaschine aus - noch ohne
## grant: die Gravur liegt erst im Vorrat, wenn ihr Meteor angekommen ist.
func roll_stamp_engraving() -> Engraving:
	var number_engravings: Array[Engraving] = []
	for engraving in Engraving.all():
		if engraving.category == Engraving.CATEGORY_NUMBER:
			number_engravings.append(engraving)
	return number_engravings[randi() % number_engravings.size()]

## Neue Glückszahl würfeln und sie in die Beschreibung jedes Lumpensammlers
## schreiben (die Karten-Instanzen, die der Dock live liest).
func _roll_lumpensammler_value() -> void:
	lumpensammler_value = randi_range(1, 6)
	for charm in owned_charms:
		if charm.id == Charm.RAG_COLLECTOR:
			charm.description = Charm.rag_collector_description(lumpensammler_value)

## Schmuckkästchen: je Vorkommen erhält jeder übrige Würfel mit 10% Chance eine
## zufällige Material-Seite (dauerhaft - Pool-Instanzen). Liefert die Anzahl.
func apply_jewelry_box(unused_dice: Array[DieDefinition]) -> int:
	var upgraded := 0
	for i in charm_ids().count(Charm.JEWELRY_BOX):
		for die in unused_dice:
			if randf() < 0.1:
				var material: DieMaterial = DieMaterial.all().pick_random()
				die.set_face_material(randi() % die.materials.size(), material.id)
				upgraded += 1
	if upgraded > 0:
		pool_changed.emit()
	return upgraded

## Rampenlicht: Wird die hervorgehobene Kombination gewertet, steigt sie
## dauerhaft eine Stufe - höchstens einmal je Runde. true = eingelöst (der
## Aufrufer spielt die Zeremonie, siehe scene_root).
func claim_spotlight(combo_key: String) -> bool:
	if spotlight_claimed_this_round or combo_key == "" or combo_key != spotlight_combo:
		return false
	spotlight_claimed_this_round = true
	combo_levels[combo_key] = combo_level(combo_key) + 1
	return true

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

## Goldener Handschlag: schafft EINE Hand den Benchmark im Alleingang, wird ihr
## erster Würfel ganz Gold - je Runde einmal. Eingebrannte Seiten mit Material
## bleiben, wie sie sind (Einbrand sperrt das Übermalen).
func apply_golden_handshake(def: DieDefinition, hand_points: int) -> bool:
	if def == null or golden_handshake_used_this_round:
		return false
	if not _clause_active(DealClause.GOLDEN_HANDSHAKE) or hand_points < effective_goal():
		return false
	for face in def.materials.size():
		if def.materials[face] != "" and RiftEffects.protects_face_value(def.rifts_on(face)):
			continue
		def.set_face_material(face, DieMaterial.GOLD)
	golden_handshake_used_this_round = true
	pool_changed.emit()
	return true

## Durchschlagpapier: die erste gewertete Hand der Runde kopiert jedes oben
## liegende Material als Gravur in den Vorrat. Liefert die Zahl der Kopien.
func apply_carbon_copy(defs: Array[DieDefinition], face_indices: Array[int],
		participating: Array[int], first_hand: bool) -> int:
	if not first_hand or not _clause_active(DealClause.CARBON_COPY):
		return 0
	var copied := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0 or face >= defs[i].materials.size():
			continue
		var material := DieMaterial.by_id(defs[i].materials[face])
		if material == null:
			continue
		var rarity: Engraving.Rarity = Engraving.MATERIAL_RARITY.get(material.id,
			Engraving.Rarity.UNCOMMON)
		grant_engraving(Engraving.material_engraving(material, rarity))
		copied += 1
	return copied

## Lasurpinsel: läuft die Firnis-Schicht ins Leere, weil die obere Seite schon
## Stufe III trägt, fällt stattdessen eine Kopie ihres Materials in den Vorrat -
## einmal je gewertetem Firnis-Würfel und Zug. Liefert die Zahl der Kopien.
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
		var material := DieMaterial.by_id(defs[i].materials[face])
		if material == null:
			continue
		var rarity: Engraving.Rarity = Engraving.MATERIAL_RARITY.get(material.id,
			Engraving.Rarity.UNCOMMON)
		grant_engraving(Engraving.material_engraving(material, rarity))
		copied += 1
	return copied

## Ethylen-Ernte: zählt ein Würfel mit dieser Seele in dieser Runde zum ersten
## Mal, wandert je VERSCHIEDENEM Material seiner sechs Seiten eine Gravur in den
## Vorrat - die Druckerpresse legt von jeder eine zweite dazu. Liefert die Zahl
## der Kopien. Die Marke hängt am Würfel-Exemplar, nicht am Pool-Platz.
func apply_material_harvest(defs: Array[DieDefinition], participating: Array[int],
		essences: Dictionary) -> int:
	var copies := 2 if charm_ids().has(Charm.PRINTING_PRESS) else 1
	var granted := 0
	for i in participating:
		if i >= defs.size() or defs[i] == null:
			continue
		if not EssenceEffects.harvests_materials_of(EssenceEffects.set_at(essences, i)):
			continue
		var key := defs[i].get_instance_id()
		if essence_harvest_used.has(key):
			continue
		essence_harvest_used[key] = true
		var seen: Array[String] = []
		for material_id in defs[i].materials:
			if material_id == "" or seen.has(material_id):
				continue
			seen.append(material_id)
			var material := DieMaterial.by_id(material_id)
			if material == null:
				continue
			var rarity: Engraving.Rarity = Engraving.MATERIAL_RARITY.get(material.id,
				Engraving.Rarity.UNCOMMON)
			for _c in copies:
				grant_engraving(Engraving.material_engraving(material, rarity))
				granted += 1
	return granted

## Meldet eine Würfel-Änderung, die AUSSERHALB von GameRun passiert ist
## (Gravur-Station, Nehmen-Effekte der Materialien) - damit alle Anzeigen über
## denselben Weg auffrischen.
## Rundenzustand der Essenzen: Löschgas und Kipp-Erlaubnis fangen neu an, dazu
## die Hand-Zähler der Runde. Der Phosphor-Speicher NICHT - er sammelt über den
## ganzen Run. Alles hängt am Würfel-Exemplar, also an seiner Instanz-id - eine
## Def wandert nie zwischen Pool-Plätzen.
func roll_essence_round_state() -> void:
	essence_smother_used.clear()
	essence_tip_used.clear()
	essence_harvest_used.clear()
	round_trigger_count = 0
	round_crit_count = 0

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

## Erster beteiligter Löschgas-Würfel, dessen Ladung diese Runde noch steht
## (-1 = keiner). Der Aufrufer verbraucht sie mit consume_smother.
func smother_slot(defs: Array[DieDefinition], slots: Array[int]) -> int:
	for i in slots:
		if i >= defs.size() or defs[i] == null:
			continue
		if EssenceEffects.smothers_farkle(defs[i].essence_id) 				and not essence_smother_used.has(defs[i].get_instance_id()):
			return i
	return -1

## Verbraucht die Löschgas-Ladung dieses Würfels für die laufende Runde. Das
## Löschen kostet: die oben liegende Seite fällt auf 1 und verliert ihr Material
## (set_face_material nimmt die Stufe mit, der Riss bleibt).
func consume_smother(die: DieDefinition, up_face: int = -1) -> void:
	if die == null:
		return
	essence_smother_used[die.get_instance_id()] = true
	if up_face < 0 or up_face >= die.faces.size():
		return
	die.faces[up_face] = 1
	die.set_face_material(up_face, "")
	note_pool_changed()

## Darf dieser Würfel diese Runde (noch) gekippt werden? Die Sumpflaterne hebt
## das Runden-Limit ganz auf.
func can_tip_die(die: DieDefinition) -> bool:
	if die == null or not EssenceEffects.can_tip(die.essence_id):
		return false
	return charm_ids().has(Charm.SWAMP_LANTERN) or not essence_tip_used.has(die.get_instance_id())

## Verbraucht die Kipp-Erlaubnis dieses Würfels für die laufende Runde.
func consume_tip(die: DieDefinition) -> void:
	if die != null:
		essence_tip_used[die.get_instance_id()] = true

## Alle Essenzen im Besitz - Grundlage der Unikat-Sperre im Angebot.
func owned_essence_ids() -> Array[String]:
	var ids: Array[String] = []
	for die in owned_pool:
		if die.essence_id != "" and not ids.has(die.essence_id):
			ids.append(die.essence_id)
	return ids

func note_pool_changed() -> void:
	pool_changed.emit()

## Tauscht zwei Pool-PLÄTZE. Das ist ANORDNUNG, nicht Ersetzung: die beiden
## Instanzen wandern mitsamt ihrer Identität an die neue Stelle, ihr Inhalt wird
## nie überschrieben (become gilt nur beim Ersetzen). Damit bleibt jeder
## instanz-gebundene Zustand - der Phosphor-Speicher, die Löschgas-Ladung -
## automatisch am richtigen Würfel.
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
	owned_pool[from_index] = owned_pool[to_index]
	owned_pool[to_index] = moved
	pool_changed.emit()
	return true

## Verbraucht genau eine Gravur der id; true, wenn eine da war.
func consume_engraving(id: String) -> bool:
	return consume_engravings(id, 1)

## Verbraucht count Gravuren derselben id - ALLES ODER NICHTS und mit genau
## EINEM Signal. Sättigen bezahlt in Dubletten: Stufe II kostet zwei Stück,
## Stufe III drei, frisch streichen eines - von nackt bis III also 1+2+3 = 6.
func consume_engravings(id: String, count: int) -> bool:
	if unlimited_engravings or count <= 0:
		return true
	var found: Array[int] = []
	for i in owned_engravings.size():
		if owned_engravings[i].id == id:
			found.append(i)
			if found.size() == count:
				break
	if found.size() < count:
		return false
	# Von hinten löschen, sonst verschieben sich die noch offenen Indizes.
	for k in range(found.size() - 1, -1, -1):
		owned_engravings.remove_at(found[k])
	engravings_changed.emit()
	return true

## Bestand einer Gravur-id (Testmodus: immer reichlich).
func engraving_stock(id: String) -> int:
	if unlimited_engravings:
		return DieMaterial.MAX_LEVEL
	var count := 0
	for engraving in owned_engravings:
		if engraving.id == id:
			count += 1
	return count

## Ob der Einsatz einer Wette bezahlbar ist. Steuerwetten sind immer platzierbar -
## sie kosten erst beim Nehmen (und reißen dort ab, siehe tax_side_bets).
func can_place_side_bet(bet: SideBet) -> bool:
	match bet.stake_kind:
		SideBet.Stake.ENGRAVINGS:
			return owned_engravings.size() >= side_bet_stake_engravings(bet)
		SideBet.Stake.CHARGE:
			return charge >= side_bet_stake_charge(bet)
		SideBet.Stake.MONEY_PER_HAND, SideBet.Stake.MONEY_PER_DIE:
			return true
	return money >= side_bet_stake(bet)

## Platziert eine Nebenwette: Einsatz sofort fällig (Geld, geopferte Gravuren
## oder Ladung), Auswertung am Rundenende.
func place_side_bet(bet: SideBet) -> void:
	match bet.stake_kind:
		SideBet.Stake.ENGRAVINGS:
			_consume_engravings(side_bet_stake_engravings(bet))
		SideBet.Stake.CHARGE:
			spend_charge(side_bet_stake_charge(bet))
		SideBet.Stake.MONEY_PER_HAND, SideBet.Stake.MONEY_PER_DIE:
			pass  # Steuerwette: die Rechnung kommt Hand für Hand
		_:
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
		paid += due
	if changed:
		side_bets_changed.emit()
	return paid

## Opfert n Gravuren vom Anfang des Inventars (Einsatz einer Gravur-Wette).
func _consume_engravings(count: int) -> void:
	var removed := false
	for i in mini(count, owned_engravings.size()):
		owned_engravings.remove_at(0)
		removed = true
	if removed:
		engravings_changed.emit()

## Wertet alle platzierten Wetten gegen die Rundenbilanz aus, schüttet die
## Gewinne aus (Gravuren oder Bargeld je payout_kind) und leert die Auslage.
## Liefert die gewonnenen Wetten für die Auszahlungs-Anzeige.
func resolve_side_bets(result: Dictionary) -> Array[SideBet]:
	var won: Array[SideBet] = []
	var factor := side_bet_payout_factor()  # Turniernacht
	for bet in active_side_bets:
		if bet.evaluate(result):
			won.append(bet)
			_pay_side_bet(bet, factor)
	active_side_bets.clear()
	side_bets_changed.emit()
	return won

## Schüttet EINEN gewonnenen Einsatz aus. Der Turniernacht-Faktor greift auf
## Geld, Gravuren und Ladung - Einzelstücke (Sonderposten, Paket, Chipstufe)
## verdoppelt er nicht.
func _pay_side_bet(bet: SideBet, factor: int) -> void:
	match bet.payout_kind:
		SideBet.Payout.MONEY:
			add_money(bet.payout_money * factor)
		SideBet.Payout.CHARGE:
			var overflow := add_charge(bet.payout_charge * factor)
			if overflow > 0:
				add_money(overflow * CHARGE_OVERFLOW_MONEY)  # volle Börse zahlt bar
		SideBet.Payout.SPECIAL:
			var special := bet.special_engraving()
			if special != null:
				grant_engraving(special)
		SideBet.Payout.PACK:
			bet.awarded_pack = Pack.roll_engraving_pack(hub_level)
			grant_pack(bet.awarded_pack)
		SideBet.Payout.COMBO_LEVEL:
			grant_combo_level(bet.target_combo)
		_:
			for i in factor:
				for engraving in bet.reward_list():
					grant_engraving(engraving)

# --- Fumble-Automaten (Slot-Bank) ---------------------------------------------

## Zahl freigeschalteter Automaten (0..3), abgeleitet aus der Hub-Stufe.
func slots_unlocked() -> int:
	var count := 0
	for level in HUB_SLOT_LEVELS:
		if hub_level >= level:
			count += 1
	return count

## Einsatz für einen Dreh an Automat machine (Freispiele drehen gratis).
func slot_spin_price(machine: int) -> int:
	if slot_spin_is_free(machine):
		return 0
	return SlotMachine.SPIN_PRICES[clampi(machine, 0, SlotMachine.MACHINE_COUNT - 1)]

## Ob der Spieler Automat machine gerade drehen darf: freigeschaltet, nicht
## stromgesperrt, in der Sitzung noch frei und der Einsatz bezahlbar.
func can_spin_slot(machine: int) -> bool:
	return slots_enabled() and machine < slots_unlocked() and slot_bank.can_spin(machine) \
		and money >= slot_spin_price(machine)

## Bezahlt den Einsatz und WÜRFELT Automat machine, schreibt das Ergebnis aber noch
## NICHT auf die Wand - das tut commit_slot erst nach der Walzen-Animation, damit
## Topf und Bust mit der Landung erscheinen und nicht schon beim Einwurf. Liefert
## den gewürfelten Block (oder [], wenn der Dreh nicht möglich war).
func spin_slot(machine: int) -> Array:
	if not can_spin_slot(machine):
		return []
	if slot_spin_is_free(machine):
		free_spins_used.append(machine)  # je Automat genau ein Gratisdreh je Runde
	else:
		add_money(-slot_spin_price(machine))
	return slot_bank.roll(machine)

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
			prizes.append(SlotPrize.from_spec(spec, hub_level, owned_essence_ids()))
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
		SlotPrize.Kind.CHARM:
			if prize.charm != null:
				for i in mult:
					_grant_charm(prize.charm.duplicate())  # voller Dock nimmt nichts mehr
		SlotPrize.Kind.DIE:
			if prize.die != null:
				for i in mult:
					_replace_pool_entry(prize.die)

## Ziel der Runde n (1-basiert) - EINZIGE Quelle der Ziel-Kurve; Rundenwechsel
## und Fahrplan lesen beide hier. Je Block verdoppelt sich der Zuwachs:
## 150 … 525 (R6), 675 … 1425 (R12), 1725 … 3225 (R18).
static func goal_for_round(n: int) -> int:
	var goal := BASE_GOAL
	for step in range(2, n + 1):
		goal += GOAL_INCREMENT * (1 << ((step - 1) / GOAL_BLOCK))
	return goal

## Nächste Runde: Ziel nachziehen und die Auslage der kommenden Runde würfeln.
## Die ERSTE Runde eines Laufs bekommt bewusst keine - der Spieler soll einmal
## würfeln, bevor das Haus ihm Konditionen anbietet.
func advance_round() -> void:
	round_number += 1
	round_goal = goal_for_round(round_number)
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
		goals.append(effective_goal_for_round(first_round + i))
	return goals

## Position des AKTUELLEN Ziels im Block (0-basiert): davor = geschafft, danach
## = noch offen.
func goal_roadmap_index(count: int) -> int:
	return (round_number - 1) % maxi(1, count)

## --- Überladung (Overcharge) --------------------------------------------------

## Punktebedarf der Stufe (1-basiert): Basisziel × Skalierung^(stufe-1) → 150,
## 300, 600 … Basis ist das WIRKSAME Ziel, damit ein Benchmark-Malus den ganzen
## Balken mitzieht (Stufen, Schwellen, Sieg-Prüfung).
func stage_size(stage: int) -> int:
	return roundi(effective_goal() * stage_size_factor() * pow(stage_scale(), stage - 1))

## Sicherungsfall: die Stufen wachsen ×4 statt ×2.
func stage_scale() -> float:
	return FUSE_FAILURE_SCALE if _clause_active(DealClause.FUSE_FAILURE) else 2.0

## Netzbrummen: jede Stufe braucht 25 % mehr Punkte.
func stage_size_factor() -> float:
	return MAINS_HUM_FACTOR if _clause_active(DealClause.MAINS_HUM) else 1.0

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

## --- Ladung (⚡) & Schwarzmarkt -----------------------------------------------
## Geräumte Überladungs-Stufen zahlen kein Geld mehr, sie prägen je eine Ladung in
## eine GEDECKELTE Börse; was nicht mehr hineinpasst, fällt zum alten Satz als Geld
## an. GameRun rechnet nur die Aufteilung (charge_split), gebucht wird in der
## Auszahlungs-Zeremonie.

## Die Börse ist die 5×5-Kondensator-Bank: der Deckel wächst NUR in ganzen
## Reihen (Vielfache von CHARGE_ROW), damit ein Ausbau als "eine Reihe erwacht"
## lesbar ist - nie als krumme Zahl.
const CHARGE_ROW := 5
const CHARGE_ROWS_MAX := 5

## Barwert einer ⚡, die nicht mehr in die Börse passt (Wett-Gewinn) - derselbe
## Satz wie eine übergelaufene Überladungs-Stufe.
const CHARGE_OVERFLOW_MONEY := 5

## Preise der Schwarzmarkt-Ware in Ladung. Der Charm kostet genau eine volle
## Reihe: schon der Grunddeckel (5) deckt den ganzen Laden ab.
const SECRET_CHARM_PRICE := 5
const SECRET_ENGRAVING_PRICE := 5
## Einmaliges Eintrittsgeld: der vergitterte Laden öffnet für diese Ladung.
const SECRET_UNLOCK_PRICE := 5
## Preis des Neuwurfs - FLACH, jedes Mal derselbe. Die alte Fibonacci-Leiter
## machte den zweiten Wurf eines Besuchs unbezahlbar; der Laden soll benutzbar
## bleiben, die ⚡ selbst ist die Schranke.
const SECRET_REROLL_BASE := 3
## Aufteilung des Wildcard-Platzes: ein Drittel Essenzwürfel, vom Rest die
## Hälfte ein Charm - so bleibt der Platz unberechenbar, ohne die festen zwei
## Plätze zu wiederholen.
const SECRET_WILDCARD_DIE_CHANCE := 0.34
const SECRET_WILDCARD_CHARM_CHANCE := 0.5

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

var charge: int = 0:
	set(value):
		if charge == value:
			return
		charge = value
		charge_changed.emit(charge)

## Freigeschaltet per Eintrittsgeld (unlock_secret_shop), danach für den Rest des
## Laufs offen. Ein frischer Lauf startet wieder vergittert.
var secret_shop_unlocked: bool = false
var secret_rerolls: int = 0
var secret_stock: Array[Dictionary] = []

## Deckel der Börse; wächst mit der Hub-Stufe wie der Überladungs-Rahmen.
func charge_cap() -> int:
	return charge_cap_rows() * CHARGE_ROW

## Erwachte Reihen der Bank je Hub-Stufe: 1 / 2 / 3 / 4 / 5 ab 1 / 3 / 5 / 7 / 10.
func charge_cap_rows() -> int:
	if hub_level >= 10:
		return 5
	if hub_level >= 7:
		return 4
	if hub_level >= 5:
		return 3
	if hub_level >= 3:
		return 2
	return 1

## Aufteilung von stages in Börse und Überlauf - reine Vorschau gegen den
## aktuellen Stand, damit die Zeremonie ihre Kometen vorab planen kann.
## stages sind ÜBERLADUNGS-STUFEN, nicht Ladungen: der Doppellader prägt zwei je
## Stufe. Was gebucht wird, zählt add_charge in Ladungen.
func charge_split(stages: int) -> Dictionary:
	return _split_charge(maxi(stages, 0) * charge_per_stage())

func _split_charge(minted: int) -> Dictionary:
	var stored := mini(minted, maxi(charge_cap() - charge, 0))
	return {"stored": stored, "overflow": minted - stored}

## Prägt count Ladungen bis zum Deckel und liefert, was nicht mehr hineinpasste -
## der Aufrufer zahlt diesen Überlauf als Geld aus.
func add_charge(count: int) -> int:
	var split := _split_charge(maxi(count, 0))
	charge += int(split["stored"])
	return int(split["overflow"])

func spend_charge(count: int) -> void:
	charge = maxi(0, charge - count)

## Freischalten des Schwarzmarkts: der Laden steht von Anfang an auf dem Tisch,
## aber vergittert - erst SECRET_UNLOCK_PRICE ⚡ heben das Gitter, dann liegt die
## erste Auslage gratis. false, wenn er offen ist oder die Ladung nicht reicht.
func unlock_secret_shop() -> bool:
	if secret_shop_unlocked or charge < SECRET_UNLOCK_PRICE:
		return false
	spend_charge(SECRET_UNLOCK_PRICE)
	secret_shop_unlocked = true
	_roll_secret_stock()
	secret_shop_discovered.emit()
	return true

## Preis des nächsten Neuwurfs - immer derselbe.
func secret_reroll_cost() -> int:
	return SECRET_REROLL_BASE

## Würfelt die GANZE Auslage neu (auch verkaufte Plätze); false, wenn die Ladung
## nicht reicht.
func reroll_secret_stock() -> bool:
	var cost := secret_reroll_cost()
	if charge < cost:
		return false
	spend_charge(cost)
	secret_rerolls += 1
	_roll_secret_stock()
	secret_stock_changed.emit()
	return true

## Kauft Platz index; je Auslage einmal, der verkaufte Platz bleibt leer.
func buy_secret_offer(index: int) -> bool:
	if index < 0 or index >= secret_stock.size():
		return false
	var offer := secret_stock[index]
	var price := int(offer[OFFER_PRICE])
	if bool(offer[OFFER_SOLD]) or charge < price:
		return false
	# Voller Dock: der Charm-Platz bleibt liegen, die Ladung wird nicht abgebucht.
	if offer[OFFER_KIND] == KIND_CHARM and charms_full():
		return false
	spend_charge(price)
	match offer[OFFER_KIND]:
		KIND_CHARM:
			var charm: Charm = offer[OFFER_ITEM]
			_grant_charm(charm)
		KIND_DIE:
			# Dieselbe Ware wie jedes Würfel-Paket: versiegelt in die Werkstatt,
			# dort sucht der Spieler selbst den Platz - kein stiller Tausch.
			var die: DieDefinition = offer[OFFER_ITEM]
			owned_packs.append(Pack.secret_die(die))
			packs_changed.emit()
		_:
			var engraving: Engraving = offer[OFFER_ITEM]
			grant_engraving(engraving)
	offer[OFFER_SOLD] = true
	secret_stock_changed.emit()
	return true

## Feste Plätze: legendärer Charm, Spezial-Gravur, Wildcard.
func _roll_secret_stock() -> void:
	secret_stock.clear()
	secret_stock.append(_secret_charm_offer())
	secret_stock.append(_secret_engraving_offer())
	secret_stock.append(_secret_wildcard_offer())

## Der dritte Platz: Essenzwürfel, Charm oder Sonderposten. Der Würfel ist der
## EINZIGE Weg an eine Schwarzmarkt-Seele - im normalen Handel liegen sie nie.
func _secret_wildcard_offer() -> Dictionary:
	if randf() < SECRET_WILDCARD_DIE_CHANCE:
		var die_offer := _secret_die_offer()
		if not die_offer.is_empty():
			return die_offer
	return _secret_charm_offer() if randf() < SECRET_WILDCARD_CHARM_CHANCE 		else _secret_engraving_offer()

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
	var die := DiceOffer.make_die(DiceOffer.TEMPLATES.pick_random(), hub_level)
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
	for charm in Charm.offerable(Charm.all(), owned_essence_ids()):
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
			var shown: Engraving = offer[OFFER_ITEM]
			listed.append(shown.id)
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
	return _secret_offer(KIND_ENGRAVING, pool.pick_random(), SECRET_ENGRAVING_PRICE)

func _secret_offer(kind: String, item: Resource, price: int) -> Dictionary:
	return {OFFER_KIND: kind, OFFER_ITEM: item, OFFER_PRICE: price, OFFER_SOLD: false}

# --- Testhilfen (Testmodus im Einstellungs-Menü) -----------------------------

## Chance je Stufe, im Testmodus noch eine höher zu steigen - sonst wären die
## Stufen II/III nur über Gravuren zu sehen.
const TEST_LEVEL_CHANCE := 0.34

## Belegt jede Seite aller Pool-Würfel mit zufälligen Materialien und hebt
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
			levels.append(0)  # ohne Material keine Stufe
		die.materials = mats
		die.levels = levels
	pool_changed.emit()

## Legt jedem Pool-Würfel 1-5 zufällige Leiterbahnen (je Seite höchstens eine,
## nur zu Nachbarn). Jeder Würfel bekommt ein frisches pointers-Array.
func randomize_all_pointers() -> void:
	for die in owned_pool:
		var pointers: Array[int] = [-1, -1, -1, -1, -1, -1]
		var faces: Array[int] = [0, 1, 2, 3, 4, 5]
		faces.shuffle()
		for i in randi_range(1, 5):
			var face: int = faces[i]
			pointers[face] = DieDefinition.adjacent_faces(face).pick_random()
		die.pointers = pointers
	pool_changed.emit()

func clear_all_pointers() -> void:
	for die in owned_pool:
		die.pointers = [-1, -1, -1, -1, -1, -1] as Array[int]
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

## Nimmt jedem Pool-Würfel die Seele - und mit dem Vakuum den zweiten Bruch,
## den allein seine Schale trägt (rift_slots).
func clear_all_essences() -> void:
	for die in owned_pool:
		die.essence_id = ""
		die.second_rifts = ["", "", "", "", "", ""] as Array[String]
	pool_changed.emit()


