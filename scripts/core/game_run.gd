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

## Ein frischer Run: leere Taschen, Runde 1, Pool voller Standardwürfel.
static func new_run() -> GameRun:
	var run := GameRun.new()
	for i in POOL_SIZE:
		run.owned_pool.append(DieDefinition.standard())
	return run

## Ids der besessenen Charms - Grundlage jeder Wertung (siehe DiceScoring/
## CharmEffects) und der Shop-Angebotsfilterung.
func charm_ids() -> Array[String]:
	var ids: Array[String] = []
	for charm in owned_charms:
		ids.append(charm.id)
	return ids

## Gutschrift (positiv) oder Abzug (negativ) - meldet money_changed.
func add_money(amount: int) -> void:
	money += amount

## Kauft eine unabhängige Kopie des Würfels in den Pool (siehe
## _replace_pool_entry). Die Kaufbarkeit hat der Shop bereits geprüft.
func purchase_die(def: DieDefinition, price: int) -> void:
	add_money(-price)
	_replace_pool_entry(def)

## Kauft ein ganzes Würfel-Bündel (siehe DiceOffer) für EINEN Preis: jeder
## Würfel ersetzt einen Pool-Eintrag (siehe _replace_pool_entry). Angebote mit
## mehr Würfeln sind einzeln schwächer (siehe DiceOffer) - Menge gegen Qualität.
func purchase_dice(defs: Array[DieDefinition], price: int) -> void:
	add_money(-price)
	for def in defs:
		_replace_pool_entry(def)

## Legt eine unabhängige Kopie von def in den Pool: ersetzt einen zufälligen
## "normalen" Eintrag (bevorzugt, damit früher gekaufte Spezialwürfel nicht
## verdrängt werden), der Pool bleibt immer POOL_SIZE groß.
func _replace_pool_entry(def: DieDefinition) -> void:
	var normal_indices: Array[int] = []
	for i in owned_pool.size():
		if owned_pool[i].style_id == "normal":
			normal_indices.append(i)

	var target_index: int
	if not normal_indices.is_empty():
		target_index = normal_indices[randi() % normal_indices.size()]
	else:
		target_index = randi() % owned_pool.size()
	owned_pool[target_index] = def.instantiate()

## Kauft einen Charm - meldet charms_changed (HUD + Tisch-Anzeige hören zu).
func purchase_charm(charm: Charm, price: int) -> void:
	add_money(-price)
	owned_charms.append(charm)
	charms_changed.emit()

## Kauft einen Coupon-Bogen: Geld abziehen, Bogen des Typs kind auswürfeln und
## per sheet_purchased zur Enthüllung melden. Die Kacheln werden hier bewusst
## NICHT gutgeschrieben - das übernimmt die Abschluss-Animation Stück für Stück
## (siehe grant_coupon/add_money), damit die Zähler sichtbar hochzählen.
func buy_coupon_sheet(kind: int, price: int) -> CouponSheet:
	add_money(-price)
	var sheet := CouponSheet.generate(kind)
	sheet_purchased.emit(sheet, kind)
	return sheet

## Legt einen Coupon ins Inventar (z.B. eine Ätzung, die vom gekauften Bogen
## "abgerissen" wurde) - meldet coupons_changed.
func grant_coupon(coupon: Coupon) -> void:
	owned_coupons.append(coupon)
	coupons_changed.emit()

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
