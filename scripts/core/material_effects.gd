class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial). Zwei Träger:
## SEITEN-Material wirkt nur, wenn die Seite oben liegt UND zur Kombination
## gehört; KANTEN-Material wirkt für den ganzen beteiligten Würfel. Beide
## stapeln. Materialien wirken NUR über die genommene Kombination - verworfene
## und gefumbelte Würfel lösen nichts aus. Zwei Aufrufpunkte: Wertungs-Boni
## (base_bonus/mult_bonus, auch in Vorschau/Farkle-Vergleich) und Nehmen-Effekte
## (apply_take_effects, einmal beim echten Nehmen).
## values/materials/edge_materials sind parallele Arrays je Wurf-Slot.

## Gold zahlt je Träger (Seite wie Kante) beim Nehmen; Goldschmied/
## Rahmenvergolder heben den Satz.
const GOLD_PAYOUT := 3
const GOLD_PAYOUT_BOOSTED := 6

## Rubin: fester Mult je Träger (Rubinschleifer addiert die Augenzahl).
const RUBY_MULT := 4

## Bernstein-Grundwert; Bernsteinzimmer hebt ihn auf 50.
const AMBER_BASE := 20

## Quecksilber-Grundfaktor; Quecksilberdampf hebt ihn auf 3.
const MERCURY_FACTOR := 2

# --- Dotierung (Stufe II): NUR das Seiten-Material, nie die Kanten. Ein
# gehobener Träger ERSETZT den Grundwert und behält den Charm-Aufschlag
# darüber (Bernsteinzimmer, Knochenleim, Quecksilberdampf & Co.).
const RUBY_CRIT := 4              # dotierter Rubin kritet statt zu addieren
const GOLD_PAYOUT_UPGRADED := 5   # dazu +$1 je Gold-Seiten-Auslösung der Nahme
const BONE_GROWTH_MIN := 3        # dotierter Knochen: mind. +3, sonst +10 %
const BONE_GROWTH_PERCENT := 10
const GLASS_SHRINK_MIN := 5       # dotiertes Glas: mind. −5, sonst −20 %
const GLASS_SHRINK_PERCENT := 20

## Glasbläserlunge: Glas schrumpft weiter, aber nie unter diesen Wert.
const GLASSBLOWER_LUNG_FLOOR := 6

## Bericht der Nehmen-Effekte für die UI.
class TakeReport:
	extends RefCounted

	var money: int = 0
	var grown: Array[int] = []  # Slots, deren Seite gewachsen ist (Knochen)
	var shrunk: Array[int] = []  # Slots, deren Seite geschrumpft ist (Glas)

## Aktivierungen des Würfels in Slot i: 1 normal, ×2 je Quecksilber-Träger
## (×3 mit Quecksilberdampf), +1 je Retrigger-Charm auf value (Hasenpfote &
## Co.). Jede Aktivierung zählt Augen und Effekte erneut.
## echo_slot: Slot, den die Echo-Kammer zusätzlich auslöst (-1 = keiner) - der
## Aufrufer kennt die Wertung, activation_count sieht nur einen einzelnen Slot.
## face_upgraded/mercury_faces: dotiertes Quecksilber OBEN löst so oft aus, wie
## der Würfel Quecksilber-Seiten hat, +1 (Dampf-Aufschlag darüber).
static func activation_count(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String], value: int = 0, echo_slot: int = -1, face_upgraded: bool = false, mercury_faces: int = 0) -> int:
	var mercury_factor := 3 if charm_ids.has(Charm.MERCURY_VAPOR) else MERCURY_FACTOR
	var count := 1
	if i < materials.size() and materials[i] == DieMaterial.MERCURY:
		count *= (mercury_faces + 1 + mercury_factor - MERCURY_FACTOR) if face_upgraded else mercury_factor
	if i < edge_materials.size() and edge_materials[i] == DieMaterial.MERCURY:
		count *= mercury_factor
	count += CharmEffects.retrigger_count(value, charm_ids)
	if i == echo_slot:
		count += CharmEffects.echo_retriggers(charm_ids)
	return count

## Basis-Bonus EINER Auslösung des Slots i - nur Träger-Effekte, ohne Augen:
## Bernstein +20 fest (Bernsteinzimmer: +50), Seite und Kante stapeln.
static func base_bonus_once(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String], face_upgraded: bool = false, eye_sum: int = 0) -> int:
	return base_once_for(
		materials[i] if i < materials.size() else "",
		edge_materials[i] if i < edge_materials.size() else "", charm_ids, face_upgraded, eye_sum)

## Wie base_bonus_once, aber direkt über Material-ids - so feuern auch
## Leiterbahn-Glieder (fremde Seite, gleiche Kante) über dieselbe Tabelle.
## eye_sum: Augensumme des Würfels - der dotierte Bernstein gibt sie statt +20.
static func base_once_for(face_material: String, edge_material: String, charm_ids: Array[String], face_upgraded: bool = false, eye_sum: int = 0) -> int:
	var amber_value := 50 if charm_ids.has(Charm.AMBER_ROOM) else AMBER_BASE
	var bonus := 0
	if face_material == DieMaterial.AMBER:
		bonus += (eye_sum + amber_value - AMBER_BASE) if face_upgraded else amber_value
	if edge_material == DieMaterial.AMBER:
		bonus += amber_value
	return bonus

## Mult-Bonus EINER Auslösung des Slots i: Rubin +4 fest (Rubinschleifer/Blood
## Diamond legen die Augenzahl drauf); Glas + rohe Augenzahl der oberen Seite.
static func mult_bonus_once(i: int, values: Array[int], materials: Array[String], edge_materials: Array[String], charm_ids: Array[String], face_upgraded: bool = false) -> int:
	return mult_once_for(
		materials[i] if i < materials.size() else "",
		edge_materials[i] if i < edge_materials.size() else "", values[i], charm_ids, face_upgraded)

## Wie mult_bonus_once über Material-ids; value ist die feuernde Augenzahl
## (beim Leiterbahn-Glied die der Zielseite). Dotierter Rubin/Glas steuern hier
## NICHTS bei - sie kriten (mult_crit_once_for); nur Schleifer/Blood Diamond
## bleiben beim Rubin additiv, damit der Krit nicht exponentiell wird.
static func mult_once_for(face_material: String, edge_material: String, value: int, charm_ids: Array[String], face_upgraded: bool = false) -> int:
	# Rubinschleifer legt die Augenzahl EINMAL drauf, der Blood Diamond je Exemplar.
	var eye_stacks := int(charm_ids.has(Charm.RUBY_GRINDER)) + charm_ids.count(Charm.BLOOD_DIAMOND)
	var ruby_value := RUBY_MULT + value * eye_stacks
	var bonus := 0
	if face_material == DieMaterial.RUBY:
		bonus += value * eye_stacks if face_upgraded else ruby_value
	elif face_material == DieMaterial.GLASS and not face_upgraded:
		bonus += value
	if edge_material == DieMaterial.RUBY:
		bonus += ruby_value
	elif edge_material == DieMaterial.GLASS:
		bonus += value
	return bonus

## Material-Krit EINER Auslösung: nur der SEITEN-Träger kann kriten, und eine
## Seite trägt genau ein Material - also höchstens ein Faktor. 1 = kein Krit.
static func mult_crit_once_for(face_material: String, value: int, _charm_ids: Array[String], face_upgraded: bool) -> int:
	if not face_upgraded:
		return 1
	match face_material:
		DieMaterial.RUBY:
			return RUBY_CRIT
		DieMaterial.GLASS:
			return maxi(1, value)
	return 1

## Dotierungs-Infos eines Slots (Form wie DiceScoring.CTX_MATERIAL_UPGRADES).
static func upgrade_of(upgrades: Dictionary, slot: int) -> Dictionary:
	return upgrades.get(slot, {})

## Basis-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests);
## Quecksilber zählt die Augen je Extra-Aktivierung erneut.
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], edge_materials: Array[String] = [], echo_slot: int = -1, upgrades: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var info := upgrade_of(upgrades, i)
		var up := bool(info.get("upgraded", false))
		var activations := activation_count(i, materials, edge_materials, charm_ids, values[i], echo_slot, up, int(info.get("mercury_faces", 0)))
		bonus += base_bonus_once(i, materials, edge_materials, charm_ids, up, int(info.get("eye_sum", 0))) * activations
		if activations > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (activations - 1)
	return bonus

## Mult-Boni der beteiligten Träger über ALLE Aktivierungen (Vorschau/Tests).
## Nur ADDITIV - ein Material-Krit (dotierter Rubin/Glas) lässt sich als Summe
## nicht ausdrücken; maßgeblich ist DiceScoring._base_and_mult.
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = [], echo_slot: int = -1, upgrades: Dictionary = {}) -> int:
	var bonus := 0
	for i in participating:
		var info := upgrade_of(upgrades, i)
		var up := bool(info.get("upgraded", false))
		var effect_count := activation_count(i, materials, edge_materials, charm_ids, values[i], echo_slot, up, int(info.get("mercury_faces", 0)))
		bonus += mult_bonus_once(i, values, materials, edge_materials, charm_ids, up) * effect_count
	return bonus

## Nehmen-Effekte: mutiert die faces der Pool-Würfel direkt (dauerhaft).
## Gold zahlt GOLD_PAYOUT je Träger (Goldschmied wie Rahmenvergolder heben Seite
## UND Kante); Knochen +1 je Träger (Knochenleim: +2, Knochenmark lässt jede
## Knochen-Auslösung ein Mal mehr feuern - je Exemplar erneut); Glas −1 je
## Träger, nie unter das Floor (Glasbläserlunge hebt es auf 6). Alles je Effekt-
## Aktivierung. Ein dotierter SEITEN-Träger ersetzt seinen Satz (Gold/Knochen/
## Glas, siehe Konstanten).
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = [], echo_slot: int = -1) -> TakeReport:
	# Goldschmied UND Rahmenvergolder heben den Satz für Seite UND Kante.
	var gold_boost := charm_ids.has(Charm.GOLDSMITH) or charm_ids.has(Charm.FRAME_GILDER)
	# Goldader legt auf JEDEN Gold-Träger denselben Zuschlag (Seite wie Kante).
	var vein := CharmEffects.gold_vein_bonus(materials, edge_materials, participating, charm_ids)
	var gold_payout := (GOLD_PAYOUT_BOOSTED if gold_boost else GOLD_PAYOUT) + vein
	var edge_gold_payout := gold_payout
	# Dotiertes Gold: $5 + $1 je Gold-SEITEN-Auslösung dieser Nahme; Charm- und
	# Goldader-Aufschlag darüber. Der Zähler steht VOR der ersten Buchung fest.
	var upgraded_gold_payout := GOLD_PAYOUT_UPGRADED + (gold_payout - GOLD_PAYOUT) \
		+ _gold_face_triggers(defs, face_indices, materials, participating, edge_materials, charm_ids, echo_slot)
	# Knochenleim hebt den Satz einmalig auf 2.
	var bone_growth := 2 if charm_ids.has(Charm.BONE_GLUE) else 1
	# Knochenmark verlängert nicht den Schritt, sondern die Zahl der Auslösungen.
	var bone_triggers := 1 + charm_ids.count(Charm.BONE_MARROW)
	# Glasbläserlunge hebt nur den Boden - geschrumpft wird weiter.
	var glass_floor := EtchingEffects.MIN_FACE_VALUE
	if charm_ids.has(Charm.GLASSBLOWER_LUNG):
		glass_floor = maxi(glass_floor, GLASSBLOWER_LUNG_FLOOR)
	var report := TakeReport.new()
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var face_upgraded := face_is_upgraded(defs[i], face)
		# Retrigger prüft den VERWANDELTEN Wert - wie in der Wertung.
		var shown := CharmEffects.transform_value(defs[i].faces[face], charm_ids)
		var effect_count := activation_count(i, materials, edge_materials, charm_ids, shown, echo_slot,
			face_upgraded, defs[i].materials.count(DieMaterial.MERCURY))

		if face_material == DieMaterial.GOLD:
			report.money += (upgraded_gold_payout if face_upgraded else gold_payout) * effect_count
		if edge_material == DieMaterial.GOLD:
			report.money += edge_gold_payout * effect_count

		# Knochen/Glas laufen Aktivierung für Aktivierung: der dotierte Satz
		# rechnet seine Prozente am schon veränderten Wert neu.
		var grew := false
		var shrunk_any := false
		for _a in effect_count:
			if face_material == DieMaterial.BONE:
				_grow_bone(defs[i], face, face_upgraded, bone_growth, bone_triggers)
				grew = true
			if edge_material == DieMaterial.BONE:
				_grow_bone(defs[i], face, false, bone_growth, bone_triggers)
				grew = true
			if face_material == DieMaterial.GLASS:
				var step := _glass_step(defs[i].faces[face]) if face_upgraded else 1
				if _shrink(defs[i], face, step, glass_floor):
					shrunk_any = true
			if edge_material == DieMaterial.GLASS and _shrink(defs[i], face, 1, glass_floor):
				shrunk_any = true
		if grew:
			report.grown.append(i)
		if shrunk_any:
			report.shrunk.append(i)

		# Leiterbahn-Glieder: je Glied EINMAL (nie × effect_count) - Seite des
		# Glieds plus Kante, Wachsen/Schrumpfen trifft die GLIED-Seite. Die
		# Dotierung des GLIEDS zählt, nicht die der oben liegenden Seite.
		for link_face in defs[i].pointer_chain(face):
			var link_material: String = defs[i].materials[link_face] if link_face < defs[i].materials.size() else ""
			var link_upgraded := face_is_upgraded(defs[i], link_face)
			if link_material == DieMaterial.GOLD:
				report.money += upgraded_gold_payout if link_upgraded else gold_payout
			if edge_material == DieMaterial.GOLD:
				report.money += edge_gold_payout
			var link_grew := false
			if link_material == DieMaterial.BONE:
				_grow_bone(defs[i], link_face, link_upgraded, bone_growth, bone_triggers)
				link_grew = true
			if edge_material == DieMaterial.BONE:
				_grow_bone(defs[i], link_face, false, bone_growth, bone_triggers)
				link_grew = true
			if link_grew and not report.grown.has(i):
				report.grown.append(i)
			var link_shrunk := false
			if link_material == DieMaterial.GLASS:
				var link_step := _glass_step(defs[i].faces[link_face]) if link_upgraded else 1
				link_shrunk = _shrink(defs[i], link_face, link_step, glass_floor)
			if edge_material == DieMaterial.GLASS and _shrink(defs[i], link_face, 1, glass_floor):
				link_shrunk = true
			if link_shrunk and not report.shrunk.has(i):
				report.shrunk.append(i)
	return report

## Ist das Material DIESER Seite dotiert? (Guard für Defs ohne volle Marke.)
static func face_is_upgraded(def: DieDefinition, face: int) -> bool:
	return def != null and face >= 0 and face < def.upgraded.size() and def.upgraded[face]

## Wie oft in DIESER Nahme eine Gold-SEITE auslöst - Aktivierungen aller
## beteiligten Slots plus Leiterbahn-Glieder, dotiert wie undotiert. Kanten
## zählen nicht: der Satz hängt an Gold-SEITEN.
static func _gold_face_triggers(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String], charm_ids: Array[String], echo_slot: int) -> int:
	var triggers := 0
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		if i < materials.size() and materials[i] == DieMaterial.GOLD:
			var shown := CharmEffects.transform_value(defs[i].faces[face], charm_ids)
			triggers += activation_count(i, materials, edge_materials, charm_ids, shown, echo_slot,
				face_is_upgraded(defs[i], face), defs[i].materials.count(DieMaterial.MERCURY))
		for link_face in defs[i].pointer_chain(face):
			if link_face < defs[i].materials.size() and defs[i].materials[link_face] == DieMaterial.GOLD:
				triggers += 1
	return triggers

## Lässt eine Knochen-Seite triggers-mal wachsen (Knochenmark). Die dotierte
## rechnet ihren Prozentschritt je Auslösung am schon gewachsenen Wert neu.
static func _grow_bone(def: DieDefinition, face: int, upgraded: bool, step: int, triggers: int) -> void:
	for _t in triggers:
		def.faces[face] += (_bone_step(def.faces[face]) + step - 1) if upgraded else step

## Wachstum einer dotierten Knochen-Seite: mind. +3, sonst 10 % (aufgerundet).
static func _bone_step(value: int) -> int:
	return maxi(BONE_GROWTH_MIN, ceili(float(value) * BONE_GROWTH_PERCENT / 100.0))

## Schrumpfen einer dotierten Glas-Seite: mind. 5, sonst 20 % (aufgerundet).
static func _glass_step(value: int) -> int:
	return maxi(GLASS_SHRINK_MIN, ceili(float(value) * GLASS_SHRINK_PERCENT / 100.0))

## Schrumpft eine Seite um step, nie unter floor_value; true, wenn sie sich bewegt hat.
static func _shrink(def: DieDefinition, face: int, step: int,
		floor_value: int = EtchingEffects.MIN_FACE_VALUE) -> bool:
	var target := maxi(floor_value, def.faces[face] - step)
	if target >= def.faces[face]:
		return false
	def.faces[face] = target
	return true
