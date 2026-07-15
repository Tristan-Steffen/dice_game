class_name GameRun
extends RefCounted
## Persistenter Zustand eines Spiellaufs: Geld, Würfel-Pool, Charms, Coupons,
## Rundenfortschritt. Reine Daten + Ökonomie, keine Nodes; UI mutiert den
## Zustand nur über die Methoden hier und hört auf die Signale.

signal money_changed(money: int)
signal charms_changed
signal coupons_changed
signal combo_upgraded(combo_key: String, new_level: int)
## Gutschrift der Kacheln folgt erst in der Abschluss-Animation (grant_coupon/add_money).
signal sheet_purchased(sheet: CouponSheet, kind: int)

const POOL_SIZE := 30
const BASE_GOAL := 150
const GOAL_INCREMENT := 50

var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

var round_number: int = 1
var round_goal: int = BASE_GOAL

## Immer genau POOL_SIZE Einträge, jeder eine EIGENE DieDefinition-Instanz,
## damit eine Ätzung nie mehrere Würfel zugleich verändert.
var owned_pool: Array[DieDefinition] = []
var owned_charms: Array[Charm] = []
var owned_coupons: Array[Coupon] = []
var unlimited_coupons: bool = false  # Testmodus: consume_coupon verbraucht nichts
## Menü-Stufen je Kombination (Key -> gegessene Gerichte); jede Stufe addiert
## Basis-Mult und Basispunkte erneut (siehe DiceScoring).
var combo_levels: Dictionary = {}

# Zustand der Effektkatalog-Charms:
var farkle_count: int = 0  # Zerbrochener Spiegel
var lumpensammler_value: int = 0  # Glückszahl, je Runde neu (0 = kein Lumpensammler)
var gravierstift_used_this_round: bool = false
var queue_bonus_slots: int = 0  # Ausziehtisch: dauerhafte Extra-Warteschlangenplätze
var newly_purchased: Array[DieDefinition] = []  # Frische Ware: zieht nächste Runde zuerst

static func new_run() -> GameRun:
	var run := GameRun.new()
	for i in POOL_SIZE:
		run.owned_pool.append(DieDefinition.standard())
	return run

## Wirkende Charm-ids für Wertungen: Totems (Papagei/Echo) liefern die id ihres
## Nachbarn statt der eigenen; ein Totem auf Totem/Leere bleibt wirkungslos.
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
		lumpensammler_value = randi_range(1, 6)
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

## Kacheln werden hier bewusst NICHT gutgeschrieben - das macht die
## Abschluss-Animation Stück für Stück. allowed_kinds beschränkt die Coupons
## auf diese Arten (sortenreine Packs); leer = gemischt.
func buy_coupon_sheet(kind: int, price: int, allowed_kinds: Array[String] = []) -> CouponSheet:
	add_money(-price)
	# Großformat: alle Packs 1×1 größer; Hausmarke: das gemischte Heft ohne Werbung.
	var ids := charm_ids()
	var extra_size := 1 if ids.has(Charm.LARGE_FORMAT) else 0
	var no_ads: bool = ids.has(Charm.HOUSE_BRAND) and allowed_kinds.is_empty()
	var sheet := CouponSheet.generate(kind, allowed_kinds, extra_size, no_ads)
	sheet_purchased.emit(sheet, kind)
	return sheet

func grant_coupon(coupon: Coupon) -> void:
	# Menü-Coupons werden nicht gehortet: das Gericht wirkt sofort.
	if coupon.kind == Coupon.KIND_MEAL:
		eat_meal(coupon.meal_combo_key())
		return
	owned_coupons.append(coupon)
	coupons_changed.emit()

## Hebt die Menü-Stufe der Kombination; der Stammgast zählt jedes Gericht
## je Vorkommen als eine Stufe mehr.
func eat_meal(combo_key: String) -> void:
	var levels := 1 + charm_ids().count(Charm.REGULAR_GUEST)
	combo_levels[combo_key] = int(combo_levels.get(combo_key, 0)) + levels
	combo_upgraded.emit(combo_key, combo_levels[combo_key])

## Rundenbeginn: Runden-Marken zurücksetzen, Mitternachtssnack isst ein
## zufälliges Gericht, Frankiermaschine schenkt 3 zufällige Ätzungen,
## Lumpensammler würfelt seine Glückszahl neu - je Vorkommen einmal.
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

## Verbraucht genau einen Coupon der id; true, wenn einer da war.
func consume_coupon(id: String) -> bool:
	if unlimited_coupons:
		return true
	for i in owned_coupons.size():
		if owned_coupons[i].id == id:
			owned_coupons.remove_at(i)
			coupons_changed.emit()
			return true
	return false

func advance_round() -> void:
	round_number += 1
	round_goal += GOAL_INCREMENT

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
