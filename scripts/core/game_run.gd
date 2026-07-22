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

const POOL_SIZE := 30
const BASE_GOAL := 150
## Zuwachs je Runde im ERSTEN Block; er verdoppelt sich mit jedem weiteren.
const GOAL_INCREMENT := 50
## Blocklänge der Ziel-Eskalation = die sechs am Hub gezeigten Stationen. Die
## Wertung wächst multiplikativ (Übertaktung, Gravuren, Charms) - ein konstanter
## Zuwachs würde daher von Block zu Block leichter.
const GOAL_BLOCK := 6

## Überladung: das Rundenziel lässt sich bis zu OVERCHARGE_STAGES-mal füllen,
## jede Stufe fordert die doppelte Punktzahl der vorigen (150 / 300 / 600 / …).
## Der Punktestand ist kumulativ, Überschuss trägt automatisch weiter. Wie viele
## Stufen tatsächlich zählen, deckelt die Hub-Stufe (max_overcharge_stages).
const OVERCHARGE_STAGES := 5

## Ausbaustufen des Hubs (Casino-Lizenz): gegen Gold jederzeit im Shop bzw. am
## Hub kaufbar. Jede Stufe schaltet STRUKTUR frei (Shop-Plätze, Blättern,
## Nebenwetten, Rarität, Überladungs-Deckel) - Zahlen-Boni bleiben Sache der Charms.
## Zehn Stufen; die oberen sind bewusst teuer (Langzeit-Ziel eines Laufs).
const HUB_MAX_LEVEL := 10
## Preise für die Aufstiege 1→2 … 9→10 (steil steigend zum High Roller).
const HUB_UPGRADE_PRICES := [8, 12, 18, 25, 35, 55, 80, 120, 170]
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
## Platzierte Nebenwetten der kommenden Runde; am Rundenende geprüft und geleert.
var active_side_bets: Array[SideBet] = []
var unlimited_engravings: bool = false  # Testmodus: consume_engraving verbraucht nichts
## Übertaktungs-Stufen je Kombination (Key -> Stufe); jede Stufe addiert
## Basis-Mult und Basispunkte erneut (siehe DiceScoring/Systemkonsole).
var combo_levels: Dictionary = {}

# Zustand der Effektkatalog-Charms:
var farkle_count: int = 0  # Zerbrochener Spiegel
var lumpensammler_value: int = 0  # Glückszahl, je Runde neu (0 = kein Lumpensammler)
var gravierstift_used_this_round: bool = false
var newly_purchased: Array[DieDefinition] = []  # Frische Ware: zieht nächste Runde zuerst

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

func add_money(amount: int) -> void:
	money += amount

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
	hub_level_changed.emit(hub_level)

## --- Aus der Hub-Stufe abgeleitete Struktur-Freischaltungen -------------------
## Alles läuft über diese Abfragen, damit Aufrufer nie rohe Stufen vergleichen.

## Wirksame Zahl an Überladungs-Stufen: 3 (bis Salon), 4 (Salon/VIP), 5 (ab Suite).
func max_overcharge_stages() -> int:
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
	newly_purchased.append(_replace_pool_entry(def))

func purchase_dice(defs: Array[DieDefinition], price: int) -> void:
	add_money(-price)
	for def in defs:
		newly_purchased.append(_replace_pool_entry(def))

## Ersetzt einen zufälligen Pool-Eintrag (bevorzugt "normal", damit frühere
## Käufe nicht verdrängt werden) durch eine unabhängige Kopie von def.
func _replace_pool_entry(def: DieDefinition) -> DieDefinition:
	var normal_indices: Array[int] = []
	for i in owned_pool.size():
		if owned_pool[i].style_id == "normal":
			normal_indices.append(i)

	var target_index: int
	if not normal_indices.is_empty():
		target_index = normal_indices[randi() % normal_indices.size()]
	else:
		target_index = randi() % owned_pool.size()
	var copy := def.instantiate()
	owned_pool[target_index] = copy
	return copy

func purchase_charm(charm: Charm, price: int) -> void:
	add_money(-price)
	owned_charms.append(charm)
	if charm.id == Charm.RAG_COLLECTOR:
		_roll_lumpensammler_value()
	charms_changed.emit()

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
		result["dice"] = pack.roll_dice(charm_ids())
	else:
		result["engravings"] = pack.roll_engravings(pack_engraving_floor())
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
	newly_purchased.append(target)

# --- Übertakten (Systemkonsole): Kombinationen ohne Stufen-Limit aufwerten ----

## Aktuelle Übertaktungs-Stufe einer Kombination.
func combo_level(combo_key: String) -> int:
	return int(combo_levels.get(combo_key, 0))

## Preis der Stufe level+1: Basis folgt der Kombinationsstärke (Basis-Mult),
## jede weitere Stufe desselben Chips kostet die Basis erneut obendrauf -
## kein Stufen-Limit, die Preiskurve ist die einzige Bremse.
static func overclock_price_at(combo_key: String, level: int) -> int:
	return (4 + DiceScoring.mult_for(combo_key)) * (level + 1)

## Preis der nächsten Stufe dieser Kombination.
func overclock_price(combo_key: String) -> int:
	return overclock_price_at(combo_key, combo_level(combo_key))

func can_overclock(combo_key: String) -> bool:
	return money >= overclock_price(combo_key)

## Kauft die nächste Stufe: Preis abziehen, Stufe heben (hebt Basispunkte und
## Multiplikator der Kombination, siehe DiceScoring).
func overclock_combo(combo_key: String) -> void:
	add_money(-overclock_price(combo_key))
	combo_levels[combo_key] = combo_level(combo_key) + 1
	combo_upgraded.emit(combo_key, combo_levels[combo_key])

## Rundenbeginn: Runden-Marken zurücksetzen, Frankiermaschine schenkt 3
## zufällige Zahl-Gravuren, Lumpensammler würfelt seine Glückszahl neu - je
## Vorkommen einmal.
func apply_round_start_charms() -> void:
	gravierstift_used_this_round = false
	var ids := charm_ids()
	if ids.has(Charm.RAG_COLLECTOR):
		_roll_lumpensammler_value()
	for i in ids.count(Charm.STAMP_MACHINE):
		var number_engravings: Array[Engraving] = []
		for engraving in Engraving.all():
			if engraving.category == Engraving.CATEGORY_NUMBER:
				number_engravings.append(engraving)
		for j in 3:
			grant_engraving(number_engravings[randi() % number_engravings.size()])

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
				die.materials[randi() % die.materials.size()] = material.id
				upgraded += 1
	return upgraded

## Verbraucht genau eine Gravur der id; true, wenn eine da war.
func consume_engraving(id: String) -> bool:
	if unlimited_engravings:
		return true
	for i in owned_engravings.size():
		if owned_engravings[i].id == id:
			owned_engravings.remove_at(i)
			engravings_changed.emit()
			return true
	return false

## Ob der Einsatz einer Wette bezahlbar ist (Geld bzw. genug Gravuren im Inventar).
func can_place_side_bet(bet: SideBet) -> bool:
	if bet.stake_kind == SideBet.Stake.ENGRAVINGS:
		return owned_engravings.size() >= bet.stake_engravings
	return money >= bet.stake

## Platziert eine Nebenwette: Einsatz sofort fällig (Geld oder geopferte
## Gravuren), Auswertung am Rundenende.
func place_side_bet(bet: SideBet) -> void:
	if bet.stake_kind == SideBet.Stake.ENGRAVINGS:
		_consume_engravings(bet.stake_engravings)
	else:
		add_money(-bet.stake)
	active_side_bets.append(bet)
	side_bets_changed.emit()

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
	for bet in active_side_bets:
		if bet.evaluate(result):
			won.append(bet)
			if bet.payout_kind == SideBet.Payout.MONEY:
				add_money(bet.payout_money)
			else:
				for engraving in bet.reward_list():
					grant_engraving(engraving)
	active_side_bets.clear()
	side_bets_changed.emit()
	return won

# --- Fumble-Automaten (Slot-Bank) ---------------------------------------------

## Zahl freigeschalteter Automaten (0..3), abgeleitet aus der Hub-Stufe.
func slots_unlocked() -> int:
	var count := 0
	for level in HUB_SLOT_LEVELS:
		if hub_level >= level:
			count += 1
	return count

## Einsatz für einen Dreh an Automat machine.
func slot_spin_price(machine: int) -> int:
	return SlotMachine.SPIN_PRICES[clampi(machine, 0, SlotMachine.MACHINE_COUNT - 1)]

## Ob der Spieler Automat machine gerade drehen darf: freigeschaltet, in der
## Sitzung noch frei und der Einsatz bezahlbar.
func can_spin_slot(machine: int) -> bool:
	return machine < slots_unlocked() and slot_bank.can_spin(machine) \
		and money >= slot_spin_price(machine)

## Bezahlt den Einsatz und dreht Automat machine. Die gelandeten Faces wandern (bei
## keinem Fumble) ins Gitter; gebucht wird erst beim Auszahlen. Liefert die FACES
## gelandeten Faces (oder [], wenn der Dreh nicht möglich war).
func spin_slot(machine: int) -> Array:
	if not can_spin_slot(machine):
		return []
	add_money(-slot_spin_price(machine))
	return slot_bank.spin(machine)

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
			prizes.append(SlotPrize.from_spec(spec))
	slot_bank.reset_session()
	return {"prizes": prizes, "runs": runs}

## Bucht EINEN Automaten-Gewinn (Aufruf beim Abflug seines Lichts).
func book_slot_prize(prize: SlotPrize) -> void:
	_book_slot_prize(prize, 1)

func _book_slot_prize(prize: SlotPrize, mult: int) -> void:
	match prize.kind:
		SlotPrize.Kind.ENGRAVING, SlotPrize.Kind.MATERIAL, SlotPrize.Kind.EDGE:
			for i in mult:
				for engraving in prize.engravings:
					grant_engraving(engraving)
		SlotPrize.Kind.CHARM:
			if prize.charm != null:
				for i in mult:
					owned_charms.append(prize.charm.duplicate())
				charms_changed.emit()
		SlotPrize.Kind.DIE:
			if prize.die != null:
				for i in mult:
					newly_purchased.append(_replace_pool_entry(prize.die))

## Ziel der Runde n (1-basiert) - EINZIGE Quelle der Ziel-Kurve; Rundenwechsel
## und Fahrplan lesen beide hier. Je Block verdoppelt sich der Zuwachs:
## 150 … 400 (R6), 500 … 1000 (R12), 1200 … 2200 (R18).
static func goal_for_round(n: int) -> int:
	var goal := BASE_GOAL
	for step in range(2, n + 1):
		goal += GOAL_INCREMENT * (1 << ((step - 1) / GOAL_BLOCK))
	return goal

func advance_round() -> void:
	round_number += 1
	round_goal = goal_for_round(round_number)

## Fahrplan-BLOCK der Runden-Ziele: die Ziele stehen zu je count fest und bleiben
## stehen, bis das letzte des Blocks geschafft ist - erst dann rückt ein frischer
## Block nach. Rein für die Hub-Anzeige.
func goal_roadmap(count: int) -> Array[int]:
	var goals: Array[int] = []
	if count <= 0:
		return goals
	var first_round := round_number - goal_roadmap_index(count)
	for i in count:
		goals.append(goal_for_round(first_round + i))
	return goals

## Position des AKTUELLEN Ziels im Block (0-basiert): davor = geschafft, danach
## = noch offen.
func goal_roadmap_index(count: int) -> int:
	return (round_number - 1) % maxi(1, count)

## --- Überladung (Overcharge) --------------------------------------------------

## Punktebedarf der Stufe (1-basiert): Basisziel × 2^(stufe-1) → 150, 300, 600 …
func stage_size(stage: int) -> int:
	return round_goal * (1 << (stage - 1))

## Kumulative Punktschwelle zum ABSCHLUSS der Stufe: Basisziel × (2^stufe - 1)
## → 150, 450, 1050, 2250, 4650.
func cumulative_threshold(stage: int) -> int:
	return round_goal * ((1 << stage) - 1)

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
		if t > old_points and t <= new_points:
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

# --- Testhilfen (Testmodus im Einstellungs-Menü) -----------------------------

## Belegt jede Seite/Kante aller Pool-Würfel mit zufälligen Materialien.
## Jeder Würfel bekommt ein frisches materials-Array (nie geteilt).
func randomize_all_materials() -> void:
	var ids: Array[String] = []
	for material in DieMaterial.all():
		ids.append(material.id)
	for die in owned_pool:
		var mats: Array[String] = []
		for i in die.materials.size():
			mats.append(ids.pick_random())
		die.materials = mats
		die.edge_material = ids.pick_random()

func clear_all_materials() -> void:
	for die in owned_pool:
		var mats: Array[String] = []
		for i in die.materials.size():
			mats.append("")
		die.materials = mats
		die.edge_material = ""

## Fügt fehlende Charms hinten an (nichts doppelt); meldet nur bei Änderung.
func grant_charms(charms: Array[Charm]) -> void:
	var owned := owned_charm_ids()
	var added := false
	for charm in charms:
		if not owned.has(charm.id):
			owned_charms.append(charm)
			added = true
	if added:
		charms_changed.emit()

## Entfernt alle Charms mit einer der ids; meldet nur bei Änderung.
func remove_charms(ids: Array) -> void:
	var kept: Array[Charm] = []
	for charm in owned_charms:
		if not ids.has(charm.id):
			kept.append(charm)
	if kept.size() != owned_charms.size():
		owned_charms = kept
		charms_changed.emit()
