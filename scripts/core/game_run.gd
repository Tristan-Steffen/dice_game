class_name GameRun
extends RefCounted
## Der persistente Zustand eines Spiellaufs ("Run"): Geld, Würfel-Sammlung,
## Charms, Coupons und Rundenfortschritt - reine Daten + Ökonomie-Logik, keine
## Nodes (analog zu DiceScoring/CharmEffects). scene_root besitzt genau eine
## Instanz und verdrahtet die Signale mit der UI; Shop (ShopController) und
## Gravur-Station (DieInspectorView) bekommen dieselbe Instanz typisiert
## gereicht und verändern den Zustand NUR über die Methoden hier.
##
## Vorher lag all das direkt auf scene_root (2000 Zeilen Node3D), das dem Shop
## eine untypisierte "game"-API reichte - testbar nur über ein FakeGame-Double,
## das die Kauflogik nachbauen musste. Jetzt testen Shop-Tests gegen den echten
## Run (siehe test/unit/test_game_run.gd, test/integration/test_shop_controller.gd),
## und ein späteres Speichern/Laden muss nur diese Klasse serialisieren.

## Geldstand hat sich geändert (Gutschrift ODER Kauf) - die HUD-Anzeige hört zu.
signal money_changed(money: int)
## Charm-Besitz hat sich geändert - HUD-Liste + physische Tisch-Charms hören zu.
signal charms_changed
## Coupon-Bestand hat sich geändert (Gutschrift oder Verbrauch) - HUD hört zu.
signal coupons_changed
## Ein Gericht wurde gegessen (siehe eat_meal): die Kombination combo_key steht
## jetzt auf new_level - die Tischliste zeichnet ihren Multiplikator neu.
signal combo_upgraded(combo_key: String, new_level: int)
## Ein Coupon-Bogen wurde gekauft - scene_root zeigt ihn als Enthüllung. Die
## Gutschrift der Kacheln folgt erst in der Abschluss-Animation (siehe
## grant_coupon/add_money, gerufen aus _play_sheet_finish_animation).
signal sheet_purchased(sheet: CouponSheet, kind: int)

const POOL_SIZE := 30  # feste Größe der Würfel-Sammlung (siehe purchase_die)
const BASE_GOAL := 150  # Rundenziel der ersten Runde
const GOAL_INCREMENT := 50  # Zielzuwachs je weiterer Runde (siehe advance_round)

## Spielwährung - läuft über den ganzen Run, nicht nur eine Runde. Jede
## Zuweisung meldet money_changed; für relative Änderungen siehe add_money.
var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

var round_number: int = 1
var round_goal: int = BASE_GOAL

## Persistente Würfel-Sammlung, immer genau POOL_SIZE Einträge - jeder eine
## EIGENE DieDefinition-Instanz (siehe DieDefinition.instantiate), damit eine
## Ätzung nie versehentlich mehrere Würfel zugleich verändert.
var owned_pool: Array[DieDefinition] = []
var owned_charms: Array[Charm] = []  # wirken auf jede Wertung dieses Runs (siehe charm_ids)
var owned_coupons: Array[Coupon] = []  # gehortete Ätzungs-Coupons, unbegrenzt (siehe grant_coupon)
## Menü-Stufen der Kombinationen (DiceScoring-Key -> gegessene Gerichte, siehe
## eat_meal): jede Stufe addiert den Basis-Multiplikator der Kombination erneut
## (siehe DiceScoring.mult_for) - Balatros Planetenkarten als Tagesmenü.
var combo_levels: Dictionary = {}

# --- Zustand der Effektkatalog-Charms (siehe Obsidian "12 Charms") ---
var farkle_count: int = 0  # Farkles des gesamten Runs (Zerbrochener Spiegel)
var lumpensammler_value: int = 0  # Glückszahl des Lumpensammlers (je Runde neu gewürfelt, 0 = keiner)
var gravierstift_used_this_round: bool = false  # Gravierstift wirkt einmal je Runde (Reset siehe apply_round_start_charms)
var queue_bonus_slots: int = 0  # Ausziehtisch: dauerhafte Extra-Plätze der Warteschlange (siehe scene_root)
## Frisch gekaufte Würfel des letzten Shop-Besuchs (dieselben Pool-Instanzen) -
## Frische Ware zieht sie in der nächsten Runde zuerst; danach geleert.
var newly_purchased: Array[DieDefinition] = []

## Ein frischer Run: leere Taschen, Runde 1, Pool voller Standardwürfel.
static func new_run() -> GameRun:
	var run := GameRun.new()
	for i in POOL_SIZE:
		run.owned_pool.append(DieDefinition.standard())
	return run

## Ids der besessenen Charms - Grundlage jeder Wertung (siehe DiceScoring/
## CharmEffects) und der Shop-Angebotsfilterung. Die Totems (Papagei/Echo)
## werden hier aufgelöst: sie liefern die id ihres NACHBARN (links bzw. rechts
## in der Besitz-Reihenfolge = Tisch-Reihenfolge, siehe CharmRowView) statt der
## eigenen - additive Effekte stapeln dadurch doppelt. Ein Totem, das auf ein
## anderes Totem oder ins Leere zeigt, bleibt wirkungslos.
func charm_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in owned_charms.size():
		var charm_id := owned_charms[i].id
		match charm_id:
			Charm.PARROT_TOTEM:
				charm_id = _neighbor_id(i - 1)
			Charm.ECHO_TOTEM:
				charm_id = _neighbor_id(i + 1)
		if charm_id != "":
			ids.append(charm_id)
	return ids

## Die ROHEN ids der besessenen Charms (ohne Totem-Auflösung) - für
## Besitz-Prüfungen (Shop: "schon gekauft") und Anzeige; für Wirkungen siehe
## charm_ids().
func owned_charm_ids() -> Array[String]:
	var ids: Array[String] = []
	for charm in owned_charms:
		ids.append(charm.id)
	return ids

## Die kopierbare id des Charms an Position index ("" bei Totem/außerhalb).
func _neighbor_id(index: int) -> String:
	if index < 0 or index >= owned_charms.size():
		return ""
	var neighbor_id := owned_charms[index].id
	if neighbor_id == Charm.PARROT_TOTEM or neighbor_id == Charm.ECHO_TOTEM:
		return ""  # Totems kopieren keine Totems (keine Endlos-Spiegel)
	return neighbor_id

## Gutschrift (positiv) oder Abzug (negativ) - meldet money_changed.
func add_money(amount: int) -> void:
	money += amount

## Kauft eine unabhängige Kopie des Würfels in den Pool (siehe
## _replace_pool_entry). Die Kaufbarkeit hat der Shop bereits geprüft.
func purchase_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	newly_purchased.append(_replace_pool_entry(def))

## Kauft ein ganzes Würfel-Bündel (siehe DiceOffer) für EINEN Preis: jeder
## Würfel ersetzt einen Pool-Eintrag (siehe _replace_pool_entry). Angebote mit
## mehr Würfeln sind einzeln schwächer (siehe DiceOffer) - Menge gegen Qualität.
func purchase_dice(defs: Array[DieDefinition], price: int) -> void:
	add_money(-price)
	for def in defs:
		newly_purchased.append(_replace_pool_entry(def))

## Legt eine unabhängige Kopie von def in den Pool: ersetzt einen zufälligen
## "normalen" Eintrag (bevorzugt, damit früher gekaufte Spezialwürfel nicht
## verdrängt werden), der Pool bleibt immer POOL_SIZE groß. Liefert die neue
## Pool-Instanz (siehe newly_purchased / Frische Ware).
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

## Kauft einen Charm - meldet charms_changed (HUD + Tisch-Anzeige hören zu).
## Der Lumpensammler würfelt beim Kauf seine Glückszahl (siehe
## lumpensammler_value / CharmEffects.rag_collector_income).
func purchase_charm(charm: Charm, price: int) -> void:
	add_money(-price)
	owned_charms.append(charm)
	if charm.id == Charm.RAG_COLLECTOR:
		lumpensammler_value = randi_range(1, 6)
	charms_changed.emit()

## Verschiebt einen besessenen Charm an eine andere Position (Drag-and-Drop
## auf dem Tisch, siehe scene_root) - Standard "Element verschieben"-Semantik
## (remove_at + insert, dazwischenliegende rücken nach). Die Reihenfolge ist
## spielrelevant: die Totems kopieren ihre NACHBARN (siehe charm_ids), und sie
## bestimmt die Tisch-Plätze (siehe CharmRowView). Meldet charms_changed.
func move_charm(from_index: int, to_index: int) -> void:
	if from_index == to_index \
			or from_index < 0 or from_index >= owned_charms.size() \
			or to_index < 0 or to_index >= owned_charms.size():
		return
	var charm := owned_charms[from_index]
	owned_charms.remove_at(from_index)
	owned_charms.insert(to_index, charm)
	charms_changed.emit()

## Kauft einen Coupon-Bogen: Geld abziehen, Bogen des Typs kind auswürfeln und
## per sheet_purchased zur Enthüllung melden. Die Kacheln werden hier bewusst
## NICHT gutgeschrieben - das übernimmt die Abschluss-Animation Stück für Stück
## (siehe grant_coupon/add_money), damit die Zähler sichtbar hochzählen.
## allowed_kinds (optional): beschränkt die echten Coupons des Bogens auf diese
## Coupon-kinds - für die sortenreinen Packs des Shops (siehe
## CouponSheet.generate / ShopController.PACKS). Leer = alle Arten gemischt.
func buy_coupon_sheet(kind: int, price: int, allowed_kinds: Array[String] = []) -> CouponSheet:
	add_money(-price)
	# Großformat: alle Packs 1×1 größer; Hausmarke: das gemischte Heft
	# (leerer Filter) enthält nie Werbeflächen.
	var ids := charm_ids()
	var extra_size := 1 if ids.has(Charm.LARGE_FORMAT) else 0
	var no_ads: bool = ids.has(Charm.HOUSE_BRAND) and allowed_kinds.is_empty()
	var sheet := CouponSheet.generate(kind, allowed_kinds, extra_size, no_ads)
	sheet_purchased.emit(sheet, kind)
	return sheet

## Legt einen Coupon ins Inventar (z.B. eine Ätzung, die vom gekauften Bogen
## "abgerissen" wurde) - meldet coupons_changed.
func grant_coupon(coupon: Coupon) -> void:
	# Menü-Coupons werden nicht gehortet: das Gericht ist sofort gegessen und
	# wertet seine Kombination dauerhaft auf (siehe eat_meal/combo_levels).
	if coupon.kind == Coupon.KIND_MEAL:
		eat_meal(coupon.meal_combo_key())
		return
	owned_coupons.append(coupon)
	coupons_changed.emit()

## Isst ein Gericht (siehe Coupon.KIND_MEAL): hebt die Menü-Stufe der
## Kombination um 1 - ihr Multiplikator wächst damit dauerhaft um seinen
## Basiswert (siehe DiceScoring.mult_for). Unbegrenzt stapelbar. Der Stammgast
## lässt jedes Gericht als zwei Stufen zählen (je Vorkommen +1 weitere).
func eat_meal(combo_key: String) -> void:
	var levels := 1 + charm_ids().count(Charm.REGULAR_GUEST)
	combo_levels[combo_key] = int(combo_levels.get(combo_key, 0)) + levels
	combo_upgraded.emit(combo_key, combo_levels[combo_key])

## Rundenbeginn-Wirkungen der Effektkatalog-Charms (von scene_root._start_new_round
## gerufen): Mitternachtssnack isst ein zufälliges Gericht, die Frankiermaschine
## schenkt drei zufällige Ätzungs-Coupons, der Lumpensammler würfelt seine
## Glückszahl neu - je Vorkommen einmal. Setzt außerdem die Runden-Marken
## zurück (Gravierstift).
func apply_round_start_charms() -> void:
	gravierstift_used_this_round = false
	var ids := charm_ids()
	if ids.has(Charm.RAG_COLLECTOR):
		lumpensammler_value = randi_range(1, 6)
	for i in ids.count(Charm.MIDNIGHT_SNACK):
		eat_meal(DiceScoring.CATEGORIES[randi() % DiceScoring.CATEGORIES.size()]["key"])
	for i in ids.count(Charm.STAMP_MACHINE):
		var etchings: Array[Coupon] = []
		for coupon in Coupon.all():
			if coupon.kind == Coupon.KIND_ETCHING:
				etchings.append(coupon)
		for j in 3:
			grant_coupon(etchings[randi() % etchings.size()])

## Schmuckkästchen: bei der Rundenziel-Auszahlung erhält jeder übergebene
## (übrige) Würfel mit 10% Chance eine zufällige Material-Seite auf einer
## zufälligen Seite - dauerhaft, da die Einträge dieselben Pool-Instanzen sind.
## Je Vorkommen des Charms ein eigener Durchgang. Liefert die Anzahl der
## veredelten Würfel (für ein UI-Feedback in scene_root).
func apply_jewelry_box(unused_dice: Array[DieDefinition]) -> int:
	var upgraded := 0
	for i in charm_ids().count(Charm.JEWELRY_BOX):
		for die in unused_dice:
			if randf() < 0.1:
				var material: DieMaterial = DieMaterial.all().pick_random()
				die.materials[randi() % die.materials.size()] = material.id
				upgraded += 1
	return upgraded

## Verbraucht genau einen Coupon der gegebenen id (siehe Coupon-Konstanten) -
## true, wenn einer da war. Von der Gravur-Station beim Anwenden einer Ätzung
## gerufen; meldet coupons_changed.
func consume_coupon(id: String) -> bool:
	for i in owned_coupons.size():
		if owned_coupons[i].id == id:
			owned_coupons.remove_at(i)
			coupons_changed.emit()
			return true
	return false

## Nächste Runde: Nummer hoch, Ziel wächst (siehe GOAL_INCREMENT). Gerufen,
## wenn der Shop nach einer geschafften Runde geschlossen wird.
func advance_round() -> void:
	round_number += 1
	round_goal += GOAL_INCREMENT
