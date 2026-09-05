class_name GameRun
extends RefCounted
## Persistenter Zustand eines Spiellaufs: Geld, Würfel-Pool, Charms, Gravuren,
## Rundenfortschritt. Reine Daten + Ökonomie, keine Nodes; UI mutiert den
## Zustand nur über die Methoden hier und hört auf die Signale.

signal money_changed(money: int)
signal charms_changed
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
signal energy_changed(value: int)
signal secret_shop_discovered
signal secret_stock_changed
## Die Serie der Werkbank hat sich geändert (Griff, Slots, verbrauchte Karten).
signal press_changed
## Ein Ladungs-Ereignis in Klartext (Aufladen, Durchbrennen, Entladen, Bucht) -
## die Chronik hängt daran; gebucht ist es hier schon.
signal charge_logged(text: String)

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
## Serien-Klauseln: der Bonus ist quantitativ, der Winkeladvokat verdoppelt ihn
## also; der Kurzschluss setzt absolut.
const CHAIN_DRIVER_SLOTS := 1
const SHORT_CIRCUIT_SLOTS := 1
const CALIBRATION_FACTOR := 0.5
## Skalierung der Überladungs-Stufen: der Sicherungsfall schlägt das Netzbrummen.
const FUSE_FAILURE_SCALE := 4.0
const MAINS_HUM_SCALE := 3.0
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
## Stellen daran ist eine Zahlenänderung, kein Code. Der beseelte Würfel kommt bei
## JEDER Stufe ab 2 obendrauf und steht darum nicht hier drin; nicht gelistete
## Stufen bekommen nur ihn. Seit ein Paket EIN Phantomwürfel ist, entscheiden die
## Stückzahlen hier, wie lang eine Reihe werden kann.
const HUB_REWARD_PACKS := {
	5: [Pack.TYPE_NUMBER, Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL],
	10: [Pack.TYPE_NUMBER, Pack.TYPE_NUMBER, Pack.TYPE_NUMBER, Pack.TYPE_MATERIAL,
		Pack.TYPE_MATERIAL, Pack.TYPE_DICE_MOD],
}
## Lizenz-Namen je Stufe (1-basiert), aufsteigende Casino-Prestige-Tiers.
const HUB_LEVEL_NAMES := ["Hinterzimmer", "Spielecke", "Lizenz", "Parkett", "Salon",
	"VIP-Lounge", "Suite", "Penthouse", "Privatclub", "High Roller"]
## Kurzbeschreibung, was der jeweilige AUFSTIEG (auf Stufe = Index+2) freischaltet.
const HUB_UPGRADE_UNLOCKS := [
	"Blättern + mehr Chips",    # → 2 Spielecke
	"Größerer Laden + Automat I",  # → 3 Lizenz
	"Nebenwetten",              # → 4 Parkett
	"Größerer Energie-Speicher", # → 5 Salon
	"Bessere Ware + Automat II",   # → 6 VIP-Lounge
	"Größerer Energie-Speicher + 3. Bündel",# → 7 Suite
	"Günstiges Blättern",       # → 8 Penthouse
	"Erlesene Ware + Automat III", # → 9 Privatclub
	"Legendäre Ware",           # → 10 High Roller
]

## Shop-Platzzahlen je Hub-Stufe (1-basiert). Der Laden wächst nicht sprunghaft,
## sondern füllt sich: Stufe 1 zeigt WENIGE, dafür große Angebote; höhere Stufen
## tauschen Kartengröße gegen Anzahl.
## SHOP_DICE_SLOTS zählt EINZELWÜRFEL, keine Pakete mehr: der Laden legt sie offen
## in die Schale. Dieselben Sprungstellen wie die beiden anderen Leitern (3/6/9),
## damit ein Ausbau alle drei Rubriken zugleich wachsen lässt - 3 auf Stufe 1,
## 6 auf Stufe 10.
## SHOP_PACK_SLOTS ist bewusst FLACH: die Kassetten-Reihe ist auf jeder Stufe
## gleich voll - sie gehört zu den festen Proportionen der Ladenseite, und ein
## wachsendes Möbel baute die Seite bei jedem Aufstieg um.
const SHOP_CHARM_SLOTS := [2, 2, 3, 3, 3, 4, 4, 4, 5, 5]
const SHOP_DICE_SLOTS  := [3, 3, 4, 4, 4, 5, 5, 5, 6, 6]
const SHOP_PACK_SLOTS  := [4, 4, 4, 4, 4, 4, 4, 4, 4, 4]

## Ab dieser Lizenzstufe führt auch das normale Regal Sonderposten - vorher gibt
## es sie einzig im Hinterzimmer.
const SHOP_SPECIAL_LEVEL := 8
## Chance je Auslage, dass einer dabei ist. Sie wächst mit der Lizenz: auf der
## letzten Stufe liegt öfter einer aus als nicht.
const SHOP_SPECIAL_CHANCE := {8: 0.25, 9: 0.4, 10: 0.55}

## Schwellen der Struktur-Freischaltungen (1-basierte Hub-Stufe).
const HUB_FLIPPING_LEVEL := 2      # Shop-Blättern
const HUB_SIDE_BETS_LEVEL := 2     # Nebenwetten installiert
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
## Hausgutschein: der nächste Charm im Laden ist gratis (verbraucht sich).
var free_charm_pending: bool = false
## Freispiele: Automaten, die ihren Gratisdreh dieser Runde schon hatten.
var free_spins_used: Array[int] = []
## Freispiel-Charm: der Gratisdreh dieses LADENBESUCHS ist verbraucht. Er hängt
## am Besuch, nicht an der Runde - begin_shop_visit setzt ihn zurück.
var free_spin_used_this_visit: bool = false

## Aktuelle Hub-Ausbaustufe (1..HUB_MAX_LEVEL). Steuert Shop-Umfang, Nebenwetten,
## Rarität und den Überladungs-Deckel (siehe die shop_*/hub_*-Abfragen unten).
var hub_level: int = 1

## Immer genau POOL_SIZE Einträge, jeder eine EIGENE DieDefinition-Instanz,
## damit eine Ätzung nie mehrere Würfel zugleich verändert.
var owned_pool: Array[DieDefinition] = []
var owned_charms: Array[Charm] = []
## Versiegelte Pakete im Werkstatt-Lager; sie warten dort beliebig lange. Eine
## Aufwertung existiert nur SO oder angewendet - einen losen Vorrat gibt es nicht.
## Das Magazin ist endlich, und der Deckel ist GEMESSEN: so viele Kassetten stehen
## in voller Größe im Magazin-Feld (PackDrawerView.capacity_for, von scene_root
## hereingeschoben - core misst keine Fenster). Er gilt für ALLES: der Kauf prüft
## vor dem Zahlen, und eine Prämie, die keinen Platz mehr findet, zerfällt zu Geld
## (PACK_FIZZLE_MONEY) - nichts verschwindet still, aber nichts schrumpft auch.
## PACK_CAPACITY ist nur noch der Rückfall ohne gemessenes Feld (Tests, Kopflos).
const PACK_CAPACITY := 20
## Zerfallswert eines Pakets, für das kein Platz mehr ist. Bewusst klein und flach:
## eine Standard-Karte trägt ein bis zwei Zellen - ihr Zerfall ist Trostgeld, kein
## Ersatz.
const PACK_FIZZLE_MONEY := 3
var pack_capacity: int = PACK_CAPACITY
var owned_packs: Array[Pack] = []
## Laufende Paket-Nummer: _stash_pack stempelt sie beim Einlagern. An ihr hängen
## Magazin-Platz, Vormerkung und Körper - Indizes brechen beim Umsortieren.
var pack_serial: int = 0
## Die Pakete des JÜNGSTEN Hub-Ausbaus, in Gewähr-Reihenfolge - Vorlage der
## Reveal-Zeremonie. Gebucht sind sie längst (upgrade_hub); das hier ist nur die
## Merkliste, wovon die Zeremonie erzählt.
var last_hub_reward_packs: Array[Pack] = []
## Wie viele Pakete desselben Ausbaus am vollen Magazin zu Geld zerfallen sind -
## die Zeremonie schickt dafür Geld statt einer Kassette los.
var last_hub_reward_fizzle: int = 0
## Der beseelte Würfel desselben Ausbaus (null = keiner). Er liegt längst im
## Ausgabefach; das hier ist die Merkliste für die Zeremonie.
var last_hub_reward_die: DieDefinition = null
## Beim Händler hinterlegte Würfel: in der Chip-Schale gekauft, aber noch nicht
## eingetauscht. Sie liegen im Laden, bis der Spieler selbst bestimmt, welchen
## Pool-Platz sie übernehmen - der Automat sucht ihn sonst allein aus, und eine
## Essenz ist angeboren und nicht wiederbeschaffbar.
var pending_dice: Array[DieDefinition] = []
## Platzierte Nebenwetten der kommenden Runde; am Rundenende geprüft und geleert.
var active_side_bets: Array[SideBet] = []
## Übertaktungs-Stufen je Kombination (Key -> Stufe); jede Stufe addiert die
## autorierten Schritte der Kategorie (siehe DiceScoring.CATEGORIES).
var combo_levels: Dictionary = {}
## Gebankte Gratis-Übertaktungen: overclock_combo greift sie ab, BEVOR es Energie
## abbucht. Die Presse speist sie nicht mehr - der Vorrat wartet auf seine nächste
## Quelle.
var free_overclocks: int = 0

## Prämie der Nebenwette Kettenreaktion: die NÄCHSTE Serie bekommt einen Slot
## mehr. Sie wird von apply_series verbraucht - ein Einmal-Schub.
var press_boost_pending: bool = false
## Dauerhaft erkaufte Serien-Slots (Taktgeber). Sie überleben die Serie, in der
## die Kassette steckte, und sterben erst mit dem Lauf.
var series_slot_bonus: int = 0

# Zustand der Effektkatalog-Charms:
var farkle_count: int = 0  # Zerbrochener Spiegel
var lumpensammler_value: int = 0  # Glückszahl, je Runde neu (0 = kein Lumpensammler)
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
## Würfel, die diese Runde schon einen Abguss genommen haben (Rune.CAST).
var rune_cast_used: Dictionary = {}
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

## --- LADUNG -------------------------------------------------------------------
## Preise der Reparatur-Bucht.
const REPAIR_ENERGY := 1
const DRAIN_MONEY := 5
const DISCHARGE_ALL_ENERGY := 5
## Wartungsvertrag (Welle 2): die Runde, BIS zu der die Bucht geschlossen bleibt
## (0 = offen). Das Zurren löscht sie wieder.
var repair_lock_round: int = 0
## Die Sicherung hat in dieser Runde schon einen Durchbrenner abgefangen.
var fuse_used_this_round: bool = false

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

## Rücknahme einer AUSGABE (Kleingedrucktes): das Geld hat den Lauf nie verlassen,
## also greift kein Einnahme-Faktor. Liefe eine Erstattung durch add_money, machte
## die Happy Hour aus jedem Paketkauf ein Geschäft - $6 hin, $24 zurück.
func refund_money(amount: int) -> void:
	money += maxi(0, amount)

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
	# >=, nicht ==: ein direkt gesetzter Stand darf nicht daran vorbeilaufen.
	if hub_level >= SECRET_UNLOCK_HUB_LEVEL:
		unlock_secret_shop()
	hub_level_changed.emit(hub_level)

## Belohnung einer frisch erreichten Stufe. JEDE Stufe ab 2 bringt EINEN beseelten
## Würfel - direkt gewürfelt und ins Ausgabefach gelegt, nicht versiegelt: ein
## Würfel ist Ware, kein Blindkauf. HUB_REWARD_PACKS legt je Stufe noch
## Gravur-Pakete obendrauf; die gehen als Kassetten ins Magazin und werden an der
## Presse geöffnet.
## Ist das Magazin voll, landen die vorderen Pakete und der Rest zerfällt zu Geld -
## last_hub_reward_fizzle merkt sich, wie viele, damit die Zeremonie statt einer
## Kassette Geld fliegen lässt. Der Würfel zerfällt nie: pending_dice hat keinen
## Deckel.
func _grant_hub_rewards(level: int) -> int:
	last_hub_reward_packs.clear()
	last_hub_reward_fizzle = 0
	last_hub_reward_die = _grant_reward_die()
	var delivery: Array[Pack] = []
	for pack_type: String in HUB_REWARD_PACKS.get(level, []):
		delivery.append(Pack.by_type(pack_type))
	for stashed in grant_packs(delivery):
		if stashed == null:
			last_hub_reward_fizzle += 1
		else:
			last_hub_reward_packs.append(stashed)
	return last_hub_reward_packs.size()

## Der EINE Weg an einen Prämien-Würfel: frisch gewürfelt, Seele garantiert,
## gratis ins Ausgabefach. Liefert das HINTERLEGTE Exemplar - die Zeremonie fliegt
## genau dieses an. null = keine Vorlage (dann fährt nichts).
func _grant_reward_die() -> DieDefinition:
	var die := DiceOffer.roll_reward_die(charm_ids(), owned_essence_ids(), hub_level)
	if die == null:
		return null
	stash_die(die, 0)
	return pending_dice[pending_dice.size() - 1]

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

## Rahmen OHNE Klausel-Wirkungen: fünf Stufen ab der ersten Lizenz - der Rahmen
## ist keine Hub-Belohnung mehr, nur Klauseln verschieben ihn.
func overcharge_frame() -> int:
	return 5

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

## Gravur-Pakete im Regal. Deutlich weniger Plätze als früher Einzel-Gravuren -
## ein Paket ersetzt drei bis vier davon.
func shop_pack_slots() -> int:
	return _slot_at(SHOP_PACK_SLOTS, 4)

## Chance auf EINEN Sonderposten in der Auslage (0 = keiner). Höchstens einer je
## Doppelseite: er belegt einen der Paket-Plätze, statt einen dazuzustellen -
## das Regal bleibt gleich breit, und er kostet einen normalen Wurf.
func shop_special_chance() -> float:
	if hub_level < SHOP_SPECIAL_LEVEL:
		return 0.0
	return float(SHOP_SPECIAL_CHANCE.get(mini(hub_level, HUB_MAX_LEVEL), 0.0))

## Kauf aus der Chip-Schale: bezahlt, aber NICHT eingesetzt - der Würfel bleibt
## beim Händler liegen, bis der Spieler selbst den Platz wählt. Hinterlegt wird
## eine eigene Instanz, denn die Auslage hält das Original weiter (Referenz-Regel).
func stash_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	pending_dice.append(def.instantiate())
	pending_dice_changed.emit()

## Bestandener Stresstest: EIN frisch gewürfelter Würfel mit Seelengarantie, gratis
## ins Ausgabefach - derselbe Weg wie die Hub-Prämie. Liefert das hinterlegte
## Exemplar (null = keine Vorlage); zerfallen kann er nicht, pending_dice ist
## unbegrenzt.
func grant_stress_reward() -> DieDefinition:
	return _grant_reward_die()

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

# --- Pakete (Kauf im Laden, Öffnen in der Werkstatt) --------------------------

## Legt ein Fixinhalt-Paket mit genau dieser Gravur ins Lager - der Weg, den seit
## dem Werkstatt-Umbau JEDE Quelle geht, die früher lose Gravuren lieferte
## (Abguss, Schmuckkästchen, Ernte, Schwarzmarkt).
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

## Der EINE Einlagerungsweg: stempelt die uid und hängt das Paket ans ENDE der
## Magazin-Ordnung - eine Lieferung verrückt nie, was der Spieler sortiert hat.
## Bewusst ohne Signal: das setzt der Aufrufer, damit eine Sammellieferung nur
## einmal meldet. Volles Magazin = null: der EINE Engpass, an dem der Deckel greift.
func _stash_pack(pack: Pack) -> Pack:
	if packs_full():
		return null
	pack_serial += 1
	pack.pack_uid = pack_serial
	owned_packs.append(pack)
	return pack

## Der gemessene Deckel, den scene_root am Magazin-Feld abliest. Idempotent, und ein
## unbrauchbarer Wert (kein Layout gemessen) lässt den Rückfall stehen.
func set_pack_capacity(value: int) -> void:
	if value <= 0 or value == pack_capacity:
		return
	pack_capacity = value

func packs_full() -> bool:
	return owned_packs.size() >= pack_capacity

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

## Verschiebt EIN Paket in der Magazin-Ordnung: bei from heraus, bei to hinein,
## alles dazwischen rückt eine Stelle - dasselbe remove/insert wie reorder_pool,
## nie ein Tausch.
func reorder_packs(from: int, to: int) -> void:
	if from < 0 or from >= owned_packs.size() or to < 0 or to >= owned_packs.size():
		return
	if from == to:
		return
	var pack := owned_packs[from]
	owned_packs.remove_at(from)
	owned_packs.insert(to, pack)
	packs_changed.emit()

## Räumt das Magazin auf: nach Sorte (SHELF_ORDER), dann Inhalt, dann uid - der
## explizite Endvergleich, weil sort_custom nicht stabil ist.
func tidy_packs() -> void:
	if owned_packs.size() < 2:
		return
	owned_packs.sort_custom(func(a: Pack, b: Pack) -> bool:
		var key_a := _tidy_key(a)
		var key_b := _tidy_key(b)
		return key_a < key_b)
	packs_changed.emit()

## Sortierschlüssel eines Pakets: Sorten-Rang, Inhalts-id, uid.
func _tidy_key(pack: Pack) -> Array:
	var shelf_rank := Pack.SHELF_ORDER.find(Pack.shelf_of(pack))
	if shelf_rank < 0:
		shelf_rank = Pack.SHELF_ORDER.size()
	var content := pack.type
	if pack.is_catalyst():
		content = pack.catalyst_id
	elif pack.is_operator():
		content = pack.operator_id
	elif pack.fixed_engraving != null:
		content = pack.fixed_engraving.id
	return [shelf_rank, content, pack.pack_uid]

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
## SECHS Schächte ab Runde 1 (Spieler-Entscheid 2026-09-04): die Hub-Leiter der
## Werkstatt ist gefallen, der Sockel steht fest. Länger wird die Reihe nur noch
## über Taktgeber, Kettentreiber und den Schub der Nebenwette.
const SERIES_LADDER := [
	{"hub": 1, "slots": 6},
]
## Deckel = BLOCK-GRÖSSE: der Block der Zeremonie ist sechs Karten, also gibt es
## keine siebte (Spieler-Entscheid 2026-09-05).
const SERIES_SLOT_CAP := 6

## Serienlänge dieses Laufs: der feste Sockel, dauerhaft erkaufte Plätze
## (Taktgeber), der Einmal-Schub der Nebenwette und die Klauseln. Der Kurzschluss
## setzt ABSOLUT - er überschreibt, was alles andere zusammengetragen hat.
## Seit dem Deckel 6 heben Taktgeber, Schub und Kettentreiber nichts mehr.
func series_slots() -> int:
	var slots := int(SERIES_LADDER[0]["slots"])
	for step: Dictionary in SERIES_LADDER:
		if hub_level >= int(step["hub"]):
			slots = int(step["slots"])
	slots += series_slot_bonus
	if press_boost_pending:
		slots += SeriesResolver.BOOST_SLOTS
	if _clause_active(DealClause.CHAIN_DRIVER):
		slots += CHAIN_DRIVER_SLOTS * deal_bonus_factor()
	if _clause_active(DealClause.SHORT_CIRCUIT):
		slots = SHORT_CIRCUIT_SLOTS
	return clampi(slots, 1, SERIES_SLOT_CAP)

## --- Die KATALYSATOREN einer Serie --------------------------------------------
## Eine Katalysator-Kassette prägt nichts; sie besetzt einen Serien-Slot als Preis
## und legt der EINEN Serie, in der sie steckt, ihre Terme bei.

const CATALYST_PROPELLANT_STEP := 1
const CATALYST_TIMER_SLOTS := 1

## Was die Katalysatoren dieser Serie zulegen: {propellant, timer, matrix, free}.
## "free" ist seit dem unbegrenzten Griff (2026-09-05) WIRKUNGSLOS - es liest
## niemand mehr; die Erdungsklemme bleibt im Katalog, ihre Wirkung ist OFFEN.
static func catalyst_terms(packs: Array[Pack]) -> Dictionary:
	var terms := {"propellant": 0, "timer": 0, "matrix": false, "free": false}
	for pack in packs:
		if pack == null:
			continue
		match pack.catalyst_id:
			Pack.CATALYST_PROPELLANT:
				terms["propellant"] = int(terms["propellant"]) + CATALYST_PROPELLANT_STEP
			Pack.CATALYST_TIMER:
				terms["timer"] = int(terms["timer"]) + CATALYST_TIMER_SLOTS
			Pack.CATALYST_MATRIX:
				terms["matrix"] = true
			Pack.CATALYST_GROUND:
				terms["free"] = true
	return terms

## Die Prämie der Nebenwette: der nächsten Serie einen Slot mehr. Sie stapelt sich
## nicht - ein zweiter Gewinn erneuert dieselbe Vormerkung.
func grant_press_boost() -> void:
	press_boost_pending = true

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
		catalyst_terms(parts["catalysts"]))

## DER GRIFF: eine Serie, EINE atomare Buchung - prüfen, rechnen, schreiben,
## Karten verbrauchen. Er ist UNBEGRENZT (Spieler-Entscheid 2026-09-05); steht
## keine prägende Karte in der Reihe, geschieht NICHTS (leeres Dictionary). Die
## SECHSER-Pflicht ist eine Fenster-Regel, hier bucht auch eine kürzere Serie.
## second_die trägt die Doppelmatrize; ohne sie bleibt er unberührt.
## Ein DURCHGEBRANNTER Zielwürfel wird verweigert - erst reparieren.
## Liefert {"projection", "second", "cards", "kept", "burned"}.
func apply_series(pack_uids: Array[int], die: DieDefinition,
		second_die: DieDefinition = null, rng: RandomNumberGenerator = null) -> Dictionary:
	if die == null or die.burned_out:
		return {}
	var chosen := _series_indices(pack_uids)
	if chosen.is_empty():
		return {}
	var parts := _series_parts(chosen)
	var nets: Array = parts["nets"]
	if nets.is_empty():
		return {}  # eine Serie aus lauter Katalysatoren prägt nicht
	var terms := catalyst_terms(parts["catalysts"])
	press_boost_pending = false  # der Schub galt genau dieser Serie
	var projection := SeriesResolver.resolve(nets, die, terms)
	_project(die, projection)
	# Der Griff HEIZT: erzwungenes +1 auf den Zielwürfel. Brennt er dabei durch,
	# bleibt die Prägung trotzdem stehen - sie wirkt nach der Reparatur wieder.
	var burned_target := charge_up_forced(die)
	var second: Dictionary = {}
	if bool(terms["matrix"]) and second_die != null and second_die != die:
		second = SeriesResolver.secondary(projection, second_die)
		_project(second_die, second)
	# Der Taktgeber ist der eine Katalysator, dessen Wirkung die Serie überlebt.
	series_slot_bonus = mini(series_slot_bonus + int(terms["timer"]), SERIES_SLOT_CAP)
	var kept := _consume_series_cards(chosen, rng)
	packs_changed.emit()
	press_changed.emit()
	note_pool_changed()
	return {"projection": projection, "second": second,
		"cards": chosen.size(), "kept": kept, "burned": burned_target}

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
		var target := int(projection["pointers"][face])
		if target >= 0:
			die.pointers[face] = target

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

# --- Übertakten (am Chip): Kombinationen ohne Stufen-Limit aufwerten ---------

## Deckel des ⚡-Preises: ab der fünften Stufe kostet jede weitere gleich viel.
const OVERCLOCK_COST_CAP := 5

## Aktuelle Übertaktungs-Stufe einer Kombination.
func combo_level(combo_key: String) -> int:
	return int(combo_levels.get(combo_key, 0))

## ⚡-Preis der Stufe level+1: eine Energie plus je bereits erklommener Stufe
## eine weitere, gedeckelt bei 5. Kein Stufen-Limit - die Energie ist die einzige
## Bremse. Bewusst OHNE Ladenpreis-Klauseln: ⚡-Preise sind überall flach; der
## Supraleiter ist der einzige Nachlass, und nie unter eine Energie.
static func overclock_cost_at(level: int, charm_ids: Array[String] = []) -> int:
	var price := mini(1 + maxi(0, level), OVERCLOCK_COST_CAP)
	return maxi(1, price - CharmEffects.overclock_discount(charm_ids))

func overclock_cost(combo_key: String) -> int:
	return overclock_cost_at(combo_level(combo_key), charm_ids())

func can_overclock(combo_key: String) -> bool:
	return free_overclocks > 0 or energy >= overclock_cost(combo_key)

## Kauft die nächste Stufe; false = weder Gutschrift noch Energie reichen (dann
## bleibt alles unverändert). Prüfen-dann-abbuchen wie buy_secret_offer. Die
## Presse-Gutschrift geht VOR der Energie - sonst verfiele sie ungenutzt.
func overclock_combo(combo_key: String) -> bool:
	if combo_key == "" or not can_overclock(combo_key):
		return false
	if free_overclocks > 0:
		free_overclocks -= 1
	else:
		spend_energy(overclock_cost(combo_key))
	grant_combo_level(combo_key)
	return true

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
	roll_essence_round_state()
	var ids := charm_ids()
	if ids.has(Charm.RAG_COLLECTOR):
		_roll_lumpensammler_value()
	throttled_combos = _round_throttled_combos()
	spotlight_claimed_this_round = false
	golden_handshake_used_this_round = false
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
		DealClause.SEED_CAPITAL:
			add_energy(instant_clause_energy(clause_id, boost))
		DealClause.DISCHARGE:
			spend_energy(DISCHARGE_ENERGY)
		DealClause.FREE_CHARM:
			free_charm_pending = true
		DealClause.FREE_SPINS:
			free_spins_used.clear()

## Energie, die diese Klausel mit der Unterschrift prägt (0 = keine). Eine Quelle
## für Buchung und Zeremonie: scene_root schickt je ⚡ einen Kometen zur Bank.
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

## Kaltverfestigung: ein Knochen auf Zeit - jede ausgelöste Seite (obere Seite
## wie gezündetes Pointer-Glied) wächst dauerhaft um so viele Augen.
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

## Stromsperre: die Automaten bleiben diese Runde aus.
func slots_enabled() -> bool:
	return not _clause_active(DealClause.POWER_CUT)

## Freispiele: dieser Automat hat seinen Gratisdreh noch offen.
func slot_spin_is_free(machine: int) -> bool:
	return _clause_active(DealClause.FREE_SPINS) and not free_spins_used.has(machine)

## Der Laden öffnet: der Gratisdreh des Freispiels lebt wieder auf.
func begin_shop_visit() -> void:
	free_spin_used_this_visit = false

## Freispiel-Charm: der erste Dreh dieses Besuchs geht aufs Haus - egal an
## welchem Automaten.
func charm_free_spin_open() -> bool:
	return not free_spin_used_this_visit and CharmEffects.has_free_spin(charm_ids())

## Quotenbonus: Auszahlungsfaktor gewonnener Nebenwetten.
func side_bet_payout_factor() -> int:
	return 2 * deal_bonus_factor() if _clause_active(DealClause.ODDS_BONUS) else 1

## Wettsteuer: Einsätze kosten doppelt (Anzeige UND Abbuchung lesen das hier).
func side_bet_stake_factor() -> int:
	return 2 if _clause_active(DealClause.BETTING_TAX) else 1

## Fälliger Bar-Einsatz einer Wette.
func side_bet_stake(bet: SideBet) -> int:
	return bet.stake * side_bet_stake_factor()

## Fälliger Paket-Einsatz einer Wette.
func side_bet_stake_packs(bet: SideBet) -> int:
	return bet.stake_packs * side_bet_stake_factor()

## Fälliger Ladungs-Einsatz einer Wette (⚡).
func side_bet_stake_energy(bet: SideBet) -> int:
	return bet.stake_energy * side_bet_stake_factor()

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

## Abguss-Rune: trägt die gewertete Seite eine Material-Gravur, wandert eine
## frische Kopie davon als versiegeltes Fixinhalt-Paket ins Lager - der Abguss
## erbt die Veredelung nicht. Der Stichel verdoppelt. Liefert die Zahl der Kopien.
## Einmal je Runde und Würfel: ohne diese Grenze druckt ein Argon-Würfel
## Materialgravuren am Fließband. Die Marke hängt am Würfel-Exemplar.
func apply_rune_cast(defs: Array[DieDefinition], faces: Array[int],
		participating: Array[int]) -> int:
	var granted := 0
	for i in participating:
		if i >= defs.size() or defs[i] == null or i >= faces.size():
			continue
		var face: int = faces[i]
		if face < 0 or face >= defs[i].materials.size():
			continue
		if not RuneEffects.casts_material(defs[i].runes_on(face)):
			continue
		# Ohne Material auf der Seite gibt es nichts abzugießen.
		var material := DieMaterial.by_id(defs[i].materials[face])
		if material == null:
			continue
		var key := defs[i].get_instance_id()
		if rune_cast_used.has(key):
			continue
		rune_cast_used[key] = true
		var copies := RuneEffects.burin_factor(charm_ids())
		for _c in copies:
			grant_material_pack(material)
			granted += 1
	return granted

## Rundenzustand der Essenzen: die Abguss-Marken und die Hand-Zähler der Runde
## fangen neu an. Der Phosphor-Speicher NICHT - er sammelt über den ganzen Run.
## Alles hängt am Würfel-Exemplar, also an seiner Instanz-id - eine Def wandert
## nie zwischen Pool-Plätzen.
func roll_essence_round_state() -> void:
	rune_cast_used.clear()
	die_scored_this_round.clear()
	round_trigger_count = 0
	round_crit_count = 0
	round_fumbles = 0
	round_bare_dice = 0
	fuse_used_this_round = false

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
	if volcanic:
		ash_fumbles += 1
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

# --- LADUNG: Regel, Buchungen und die Reparatur-Bucht ---------------------------

## Die Ladungs-Regel dieser Runde als EIN Dictionary. Charms und Klauseln füllen
## sie ab Welle 2; heute steht der Standard.
func charge_rule() -> Dictionary:
	return DiceScoring.default_charge_rule()

## "Würfel N" - die Vorrats-Position, an der die Chronik ihn nennt.
func _die_label(die: DieDefinition) -> String:
	var index := owned_pool.find(die)
	return "Würfel %d" % (index + 1) if index >= 0 else "Ein Würfel"

func _log_charge(die: DieDefinition, burned: bool) -> void:
	if burned:
		charge_logged.emit("%s brennt durch" % _die_label(die))
	else:
		charge_logged.emit("%s lädt auf %d" % [_die_label(die), die.charge])

## Das EINE erzwungene +1 (Fumble, Griff, Klausel): kein Wurf, sondern sicher -
## und an der Spitze sicher durchgebrannt, sofern nicht die Seele immun ist, die
## Regel das Brennen verbietet oder die Sicherung es abfängt.
## true = der Würfel ist dabei durchgebrannt.
func charge_up_forced(die: DieDefinition) -> bool:
	if die == null or die.burned_out:
		return false
	var rule := charge_rule()
	var cap := int(rule.get("cap", DieDefinition.CHARGE_MAX))
	var souls: Array[String] = [die.essence_id]
	var immune := EssenceEffects.immune_to_burnout(souls)
	if die.charge >= cap:
		if immune or not bool(rule.get("can_burn", true)):
			return false
		if bool(rule.get("fuse_armed", false)) and not fuse_used_this_round:
			fuse_used_this_round = true
			die.charge = 0
			charge_logged.emit("%s: die Sicherung hält" % _die_label(die))
			return false
		die.burn_out()
		_log_charge(die, true)
		return true
	die.charge = mini(cap, die.charge + 1)
	_log_charge(die, false)
	return false

## Bucht die Ladung einer genommenen Hand: die END-Stände der (auf ECHTE Slots
## umgerechneten) Aufschlüsselung wandern in die Defs. slots sind die gewerteten
## Slots wie bei note_dice_scored; leer heißt "alles, was die Hand nennt".
## Liefert je Änderung {die, slot, before, after, burned} für die Zeremonie -
## gebucht ist hier schon alles (Buchung vor dem Licht).
func book_charge_results(defs: Array[DieDefinition], breakdown: Dictionary,
		slots: Array[int] = []) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var charges: Dictionary = breakdown.get("charges_after", {})
	var burned: Array = breakdown.get("burned_after", [])
	if bool(breakdown.get("fuse_used", false)):
		fuse_used_this_round = true
	var touched: Array[int] = []
	for key in charges:
		touched.append(int(key))
	touched.sort()
	for slot in touched:
		if not slots.is_empty() and not slots.has(slot):
			continue
		if slot < 0 or slot >= defs.size() or defs[slot] == null:
			continue
		var die: DieDefinition = defs[slot]
		if die.burned_out:
			continue
		var before := die.charge
		var burns := burned.has(slot)
		die.charge = maxi(0, int(charges[slot]))
		if burns:
			die.burn_out()
		if before == die.charge and not burns:
			continue
		_log_charge(die, burns)
		changes.append({"die": die, "slot": slot, "before": before,
			"after": die.charge, "burned": burns})
	if not changes.is_empty():
		note_pool_changed()
	return changes

## Fumble: jeder Würfel, der beim ECHTEN Fumble in der Grube liegt, bekommt ein
## erzwungenes +1. Ergebnisliste wie book_charge_results.
func charge_fumble_dice(defs: Array[DieDefinition]) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for i in defs.size():
		var die: DieDefinition = defs[i]
		if die == null or die.burned_out:
			continue
		var before := die.charge
		var burned := charge_up_forced(die)
		if before == die.charge and not burned:
			continue
		changes.append({"die": die, "slot": i, "before": before,
			"after": die.charge, "burned": burned})
	if not changes.is_empty():
		note_pool_changed()
	return changes

## Dauerbetrieb/Dauerstrom (Welle 2): nicht gespielte Würfel entladen gar nicht.
func _cooling_spares_unplayed() -> bool:
	return false

## Erdung (Welle 2): am Rundenende entladen ALLE Würfel, auch die gespielten.
func _cooling_hits_all() -> bool:
	return false

## Rundenende: jeder Vorrats-Würfel, der in DIESER Runde nicht gewertet hat,
## verliert eine Ladung. Durchgebrannte sind ausgenommen - sie entladen nicht,
## sie werden repariert.
func cool_unplayed_dice() -> Array[DieDefinition]:
	var cooled: Array[DieDefinition] = []
	if _cooling_spares_unplayed():
		return cooled
	var hits_all := _cooling_hits_all()
	for die in owned_pool:
		if die == null or die.burned_out or die.charge <= 0:
			continue
		if not hits_all and die_scored_this_round.has(die.get_instance_id()):
			continue
		if die.charge_down():
			cooled.append(die)
	if not cooled.is_empty():
		charge_logged.emit("%d Würfel entladen" % cooled.size())
		note_pool_changed()
	return cooled

## Der Wartungsvertrag sperrt die Bucht für das Fenster VOR der nächsten Runde.
func repair_locked() -> bool:
	return repair_lock_round > 0 and round_number <= repair_lock_round

## Das Zurren der Runde löscht die Sperre, für die sie galt.
func note_round_committed() -> void:
	if repair_lock_round > 0 and round_number >= repair_lock_round:
		repair_lock_round = 0

## Reparatur: durchgebrannt -> Ladung 0, für REPAIR_ENERGY ⚡. Prüfen-dann-
## abbuchen wie overclock_combo; false = es wurde nichts gebucht.
func repair_die(die: DieDefinition) -> bool:
	if die == null or not die.burned_out or repair_locked():
		return false
	if energy < REPAIR_ENERGY:
		return false
	spend_energy(REPAIR_ENERGY)
	die.repair()
	charge_logged.emit("%s repariert (%d ⚡)" % [_die_label(die), REPAIR_ENERGY])
	note_pool_changed()
	return true

## Ableiten: EINE Stufe herunter, für DRAIN_MONEY $.
func drain_die(die: DieDefinition) -> bool:
	if die == null or die.burned_out or die.charge <= 0 or repair_locked():
		return false
	if money < DRAIN_MONEY:
		return false
	add_money(-DRAIN_MONEY)
	die.charge_down()
	charge_logged.emit("%s abgeleitet auf %d ($%d)" % [_die_label(die), die.charge, DRAIN_MONEY])
	note_pool_changed()
	return true

## Alle entladen: jede Ladung auf 0 für DISCHARGE_ALL_ENERGY ⚡. Durchgebrannte
## bleiben durchgebrannt - das ist die Reparatur. Steht ohnehin alles kalt, wird
## nichts gebucht.
func discharge_all() -> bool:
	if repair_locked() or energy < DISCHARGE_ALL_ENERGY:
		return false
	var hot := 0
	for die in owned_pool:
		if die != null and not die.burned_out and die.charge > 0:
			hot += 1
	if hot == 0:
		return false
	spend_energy(DISCHARGE_ALL_ENERGY)
	for die in owned_pool:
		if die != null and not die.burned_out:
			die.charge = 0
	charge_logged.emit("%d Würfel entladen (%d ⚡)" % [hot, DISCHARGE_ALL_ENERGY])
	note_pool_changed()
	return true

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
		Charm.FEATURE_SECRET_SHOP: secret_shop_unlocked,
		Charm.FEATURE_SLOT_MACHINE: slots_unlocked() > 0,
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
		if not Pack.tierable(pack):
			continue
		var key := SideBet.pack_stock_key(pack.type, pack.tier)
		out[key] = int(out.get(key, 0)) + 1
	return out

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
		if Pack.tierable(pack) and pack.type == bet.stake_pack_type \
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
	match bet.stake_kind:
		SideBet.Stake.PACKS:
			_consume_packs(stake_packs_for(bet))
		SideBet.Stake.ENERGY:
			spend_energy(side_bet_stake_energy(bet))
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
func resolve_side_bets(result: Dictionary) -> Array[SideBet]:
	var won: Array[SideBet] = []
	var factor := side_bet_payout_factor()  # Quotenbonus
	for bet in active_side_bets:
		if bet.evaluate(result):
			won.append(bet)
			_pay_side_bet(bet, factor)
	active_side_bets.clear()
	side_bets_changed.emit()
	return won

## Schüttet EINEN gewonnenen Einsatz aus. Der Quotenbonus-Faktor greift auf
## Geld, Ware und Energie - Einzelstücke (Sonderposten, Paket, Chipstufe)
## verdoppelt er nicht. JEDES gewährte Paket wird in awarded_packs GEMERKT
## (und jedes am vollen Magazin zerfallene gezählt): die Auszahlungs-Seite
## hält die Kassetten bis zum Kassieren zurück und zielt dann auf ihre uids.
func _pay_side_bet(bet: SideBet, factor: int) -> void:
	bet.awarded_packs.clear()
	bet.awarded_fizzled = 0
	match bet.payout_kind:
		SideBet.Payout.MONEY:
			# Quotenblatt hebt NUR das Bargeld - Energie und Ware bleiben.
			add_money(CharmEffects.side_bet_money(bet.payout_money * factor, charm_ids()))
		SideBet.Payout.ENERGY:
			var overflow := add_energy(bet.payout_energy * factor)
			if overflow > 0:
				add_money(overflow * ENERGY_OVERFLOW_MONEY)  # volle Börse zahlt bar
		SideBet.Payout.SPECIAL:
			# Wie beim Paket-Gewinn gemerkt: die Zeremonie zielt auf SEINE uid.
			bet.awarded_pack = grant_engraving_pack(bet.special_engraving())
			bet.note_awarded(bet.awarded_pack)
		SideBet.Payout.PACK:
			# null = volles Magazin: der Gewinn ist zu Geld zerfallen, und die
			# Zeremonie schickt darum Geld statt einer Kassette los.
			bet.awarded_pack = grant_pack(bet.reward_pack())
			bet.note_awarded(bet.awarded_pack)
		SideBet.Payout.COMBO_LEVEL:
			grant_combo_level(bet.target_combo)
		SideBet.Payout.PRESS_BOOST:
			# Einzelstück wie der Sonderposten: der Quotenbonus verdoppelt es nicht.
			grant_press_boost()
		_:
			for i in factor:
				for pack in bet.reward_list():
					bet.note_awarded(grant_pack(pack))

# --- Fumble-Automaten (Slot-Bank) ---------------------------------------------

## Zahl freigeschalteter Automaten (0..3), abgeleitet aus der Hub-Stufe.
func slots_unlocked() -> int:
	var count := 0
	for level in HUB_SLOT_LEVELS:
		if hub_level >= level:
			count += 1
	return count

## Einsatz für einen Dreh an Automat machine in ⚡ (Freispiele drehen gratis).
func slot_spin_energy(machine: int) -> int:
	if slot_spin_is_free(machine) or charm_free_spin_open():
		return 0
	return SlotMachine.SPIN_ENERGYS[clampi(machine, 0, SlotMachine.MACHINE_COUNT - 1)]

## Ob der Spieler Automat machine gerade drehen darf: freigeschaltet, nicht
## stromgesperrt, in der Sitzung noch frei und der Einsatz bezahlbar.
func can_spin_slot(machine: int) -> bool:
	return slots_enabled() and machine < slots_unlocked() and slot_bank.can_spin(machine) \
		and energy >= slot_spin_energy(machine)

## Bezahlt den Einsatz und WÜRFELT Automat machine, schreibt das Ergebnis aber noch
## NICHT auf die Wand - das tut commit_slot erst nach der Walzen-Animation, damit
## Topf und Bust mit der Landung erscheinen und nicht schon beim Einwurf. Liefert
## den gewürfelten Block (oder [], wenn der Dreh nicht möglich war).
func spin_slot(machine: int) -> Array:
	if not can_spin_slot(machine):
		return []
	if slot_spin_is_free(machine):
		free_spins_used.append(machine)  # je Automat genau ein Gratisdreh je Runde
	elif charm_free_spin_open():
		free_spin_used_this_visit = true  # ein Freispiel je Besuch, nicht je Automat
	else:
		spend_energy(slot_spin_energy(machine))
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
			prizes.append(SlotPrize.from_spec(spec, hub_level))
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

## Die Börse ist die 5×5-Kondensator-Bank: der Deckel wächst NUR in ganzen
## Reihen (Vielfache von ENERGY_ROW), damit ein Ausbau als "eine Reihe erwacht"
## lesbar ist - nie als krumme Zahl.
const ENERGY_ROW := 5
const ENERGY_ROWS_MAX := 5

## Barwert einer ⚡, die nicht mehr in die Börse passt (Wett-Gewinn) - derselbe
## Satz wie eine übergelaufene Überladungs-Stufe.
const ENERGY_OVERFLOW_MONEY := 5

## Preise der Schwarzmarkt-Ware in Energie. Der Charm kostet genau eine volle
## Reihe: schon der Grunddeckel (5) deckt den ganzen Laden ab.
const SECRET_CHARM_PRICE := 5

## Bündel des Sonderposten-Platzes: Menge, ⚡-Preis und Ziehgewicht. Ein Bündel
## ist EINE Datenkarte mit mehreren Stücken darin - je größer, desto seltener,
## aber der Stückpreis fällt (3 / 2,33 / 2 ⚡).
const SECRET_SPECIAL_BUNDLES := [
	{"count": 1, "price": 3, "weight": 3},
	{"count": 3, "price": 7, "weight": 2},
	{"count": 5, "price": 10, "weight": 1},
]
## Lizenzstufe, ab der das Gitter fällt - der Zutritt ist Teil des Ausbaus,
## nicht der erste Energie-Posten des Laufs.
const SECRET_UNLOCK_HUB_LEVEL := 5
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
## Stückzahl EINER Karte (Sonderposten-Bündel); alles andere liegt einzeln.
const OFFER_COUNT := "count"
const OFFER_SOLD := "sold"
const KIND_CHARM := "charm"
const KIND_ENGRAVING := "engraving"
const KIND_DIE := "die"
## Katalysator-Kassette: die zweite Familie des Sonderbestands, also auch die
## zweite Ware des Sonderposten-Platzes.
const KIND_CATALYST := "catalyst"

## Umrechnungskurs des Hinterzimmers: EIN Sonderposten kostet dort 3 ⚡, im Regal
## $30 - zehn Dollar auf die Energie. Jede Ware, die beide Läden führen (die
## Katalysatoren), preist sich danach, statt eine zweite Tabelle zu pflegen.
const SECRET_MONEY_PER_ENERGY := 10
## Anteil der Katalysatoren am Sonderposten-Platz - die Gravur bleibt die Regel.
const SECRET_CATALYST_CHANCE := 0.35

## ⚡-Preis eines Dollar-Preises im Hinterzimmer, aufgerundet und nie unter 1.
static func secret_energy_price(money_price: int) -> int:
	return maxi(1, ceili(float(money_price) / float(SECRET_MONEY_PER_ENERGY)))

var energy: int = 0:
	set(value):
		if energy == value:
			return
		energy = value
		energy_changed.emit(energy)

## Freigeschaltet mit der Lizenzstufe (unlock_secret_shop), danach für den Rest
## des Laufs offen. Ein frischer Lauf startet wieder vergittert.
var secret_shop_unlocked: bool = false
var secret_rerolls: int = 0
var secret_stock: Array[Dictionary] = []

## Deckel der Börse; wächst mit der Hub-Stufe wie der Überladungs-Rahmen.
func energy_cap() -> int:
	return energy_cap_rows() * ENERGY_ROW

## Erwachte Reihen der Bank je Hub-Stufe: 1 / 2 / 3 / 4 / 5 ab 1 / 3 / 5 / 7 / 10.
func energy_cap_rows() -> int:
	if hub_level >= 10:
		return ENERGY_ROWS_MAX
	if hub_level >= 7:
		return 4
	if hub_level >= 5:
		return 3
	if hub_level >= 3:
		return 2
	return 1

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

## Freischalten des Schwarzmarkts: der Laden steht von Anfang an auf dem Tisch,
## aber vergittert - die Lizenzstufe hebt das Gitter, dann liegt die erste
## Auslage gratis. false, wenn er schon offen ist.
func unlock_secret_shop() -> bool:
	if secret_shop_unlocked:
		return false
	secret_shop_unlocked = true
	_roll_secret_stock()
	secret_shop_discovered.emit()
	return true

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
	return maxi(1, price - CharmEffects.secret_price_cut(charm_ids()))

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
	# Volles Magazin: alles VERSIEGELTE sperrt der Deckel wie eine knappe Börse -
	# prüfen vor dem Zahlen, sonst zerfiele bezahlte Ware zu $3. Der Würfel geht
	# ins Ausgabefach und kennt darum keinen Deckel.
	if offer[OFFER_KIND] != KIND_CHARM and offer[OFFER_KIND] != KIND_DIE and packs_full():
		return false
	spend_energy(price)
	match offer[OFFER_KIND]:
		KIND_CHARM:
			var charm: Charm = offer[OFFER_ITEM]
			_grant_charm(charm)
		KIND_DIE:
			# Ware wie jeder gekaufte Würfel: ab ins Ausgabefach, den Pool-Platz
			# sucht der Spieler selbst - kein stiller Tausch.
			var die: DieDefinition = offer[OFFER_ITEM]
			stash_die(die, 0)
		KIND_CATALYST:
			# Die Kassette liegt fertig im Angebot - sie geht, wie sie ist.
			grant_pack(offer[OFFER_ITEM] as Pack)
		_:
			# Auch der Sonderposten geht versiegelt raus - offen darf nichts warten.
			# Ein Bündel bleibt dabei EINE Karte mit mehreren Stücken darin.
			grant_pack(Pack.fixed_engraving_pack(offer[OFFER_ITEM] as Engraving,
				int(offer.get(OFFER_COUNT, 1))))
	offer[OFFER_SOLD] = true
	secret_stock_changed.emit()
	return true

## Feste Plätze: legendärer Charm, Spezial-Gravur, Wildcard.
func _roll_secret_stock() -> void:
	secret_stock.clear()
	secret_stock.append(_secret_charm_offer())
	secret_stock.append(_secret_special_offer())
	secret_stock.append(_secret_wildcard_offer())

## Der Sonderposten-Platz führt beide Familien des Sonderbestands: meist ein
## Gravur-Bündel, manchmal eine Katalysator-Kassette. EIN Eingang, damit der
## Wildcard-Platz dieselbe Auswahl bekommt.
func _secret_special_offer() -> Dictionary:
	if randf() < SECRET_CATALYST_CHANCE:
		var card := _secret_catalyst_offer()
		if not card.is_empty():
			return card
	return _secret_engraving_offer()

## Eine Katalysator-Kassette, die nicht schon in der Auslage liegt - zwei gleiche
## Plätze lesen sich als Fehler. Liegen alle vier, weicht der Platz auf eine
## Gravur aus statt leer zu bleiben.
func _secret_catalyst_offer() -> Dictionary:
	var listed: Array[String] = []
	for offer in secret_stock:
		if offer[OFFER_KIND] == KIND_CATALYST:
			var shown: Pack = offer[OFFER_ITEM]
			listed.append(shown.catalyst_id)
	var pool: Array[String] = []
	for id in Pack.catalyst_ids():
		if not listed.has(id):
			pool.append(id)
	if pool.is_empty():
		return {}
	var pick: String = pool.pick_random()
	return _secret_offer(KIND_CATALYST, Pack.catalyst(pick),
		secret_energy_price(Pack.catalyst_price(pick)))

## Der dritte Platz würfelt nur noch WARE: Essenzwürfel oder Sonderbestand. Der
## Würfel ist der EINZIGE Weg an eine Schwarzmarkt-Seele - im normalen Handel
## liegen sie nie. Kein Charm-Zweig mehr: das Hinterzimmer hat genau EINEN
## Karten-Sitz, und der gehört dem legendären Platz - nie zwei Karten, nie null
## (nur der Erschöpfungs-Rückfall des legendären Topfes lässt ihn leer).
func _secret_wildcard_offer() -> Dictionary:
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
	var bundle := _roll_special_bundle()
	return _secret_offer(KIND_ENGRAVING, pool.pick_random(), int(bundle["price"]),
		int(bundle["count"]))

## Gewichteter Griff in SECRET_SPECIAL_BUNDLES - das große Bündel ist der Fund,
## nicht der Regelfall.
func _roll_special_bundle() -> Dictionary:
	var total := 0
	for bundle: Dictionary in SECRET_SPECIAL_BUNDLES:
		total += int(bundle["weight"])
	var pick := randi() % maxi(total, 1)
	for bundle: Dictionary in SECRET_SPECIAL_BUNDLES:
		pick -= int(bundle["weight"])
		if pick < 0:
			return bundle
	return SECRET_SPECIAL_BUNDLES[0]

func _secret_offer(kind: String, item: Resource, price: int, count := 1) -> Dictionary:
	return {OFFER_KIND: kind, OFFER_ITEM: item, OFFER_PRICE: price,
		OFFER_COUNT: count, OFFER_SOLD: false}

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

## Legt jedem Pool-Würfel 1-5 zufällige Pointer (je Seite höchstens eine,
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

## Nimmt jedem Pool-Würfel die Seele - und mit dem Vakuum den zweite Rune,
## den allein seine Schale trägt (rune_slots).
func clear_all_essences() -> void:
	for die in owned_pool:
		die.essence_id = ""
		die.second_runes = ["", "", "", "", "", ""] as Array[String]
	pool_changed.emit()


