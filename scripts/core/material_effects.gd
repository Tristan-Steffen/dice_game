class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial). Zwei Träger:
## SEITEN-Material wirkt nur, wenn die Seite oben liegt UND zur Kombination
## gehört; KANTEN-Material wirkt für den ganzen beteiligten Würfel. Beide
## stapeln. Materialien wirken NUR über die genommene Kombination - verworfene
## und gefumbelte Würfel lösen nichts aus. Zwei Aufrufpunkte: Wertungs-Boni
## (base_bonus/mult_bonus, auch in Vorschau/Farkle-Vergleich) und Nehmen-Effekte
## (apply_take_effects, einmal beim echten Nehmen).
## values/materials/edge_materials sind parallele Arrays je Wurf-Slot.

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
static func activation_count(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String], value: int = 0, echo_slot: int = -1) -> int:
	var mercury_factor := 3 if charm_ids.has(Charm.MERCURY_VAPOR) else 2
	var count := 1
	if i < materials.size() and materials[i] == DieMaterial.MERCURY:
		count *= mercury_factor
	if i < edge_materials.size() and edge_materials[i] == DieMaterial.MERCURY:
		count *= mercury_factor
	count += CharmEffects.retrigger_count(value, charm_ids)
	if i == echo_slot:
		count += CharmEffects.echo_retriggers(charm_ids)
	return count

## Wie oft die MATERIAL-EFFEKTE feuern: Aktivierungen, zusätzlich ×2 durch die
## Legierung bei Seite+Kante - anders als Quecksilber ohne das Augen-Zählen.
static func effect_activations(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String], value: int = 0, echo_slot: int = -1) -> int:
	var count := activation_count(i, materials, edge_materials, charm_ids, value, echo_slot)
	if charm_ids.has(Charm.ALLOY):
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		if face_material != "" and edge_material != "":
			count *= 2
	return count

## Basis-Boni der beteiligten Träger: Bernstein +20 fest (Bernsteinzimmer: +50);
## Quecksilber zählt die Augen je Extra-Aktivierung erneut.
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], edge_materials: Array[String] = [], echo_slot: int = -1) -> int:
	var amber_value := 50 if charm_ids.has(Charm.AMBER_ROOM) else 20
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var activations := activation_count(i, materials, edge_materials, charm_ids, values[i], echo_slot)
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids, values[i], echo_slot)
		if face_material == DieMaterial.AMBER:
			bonus += amber_value * effect_count
		if edge_material == DieMaterial.AMBER:
			bonus += amber_value * effect_count
		if activations > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (activations - 1)
	return bonus

## Mult-Boni der beteiligten Träger: Rubin +4 fest (Rubinschleifer: +10);
## Glas + rohe Augenzahl der oben liegenden Seite.
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = [], echo_slot: int = -1) -> int:
	var ruby_value := 10 if charm_ids.has(Charm.RUBY_GRINDER) else 4
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids, values[i], echo_slot)
		if face_material == DieMaterial.RUBY:
			bonus += ruby_value * effect_count
		if edge_material == DieMaterial.RUBY:
			bonus += ruby_value * effect_count
		if face_material == DieMaterial.GLASS:
			bonus += values[i] * effect_count
		if edge_material == DieMaterial.GLASS:
			bonus += values[i] * effect_count
	return bonus

## Nehmen-Effekte: mutiert die faces der Pool-Würfel direkt (dauerhaft).
## Gold zahlt +$1 je Träger (Seite: Goldschmied $2, Kante: Rahmenvergolder $2);
## Knochen +1 je Träger (Knochenleim: +2, nach oben offen); Glas −1 je Träger,
## nie unter das Floor (Glasbläserlunge: gar nicht). Alles je Effekt-Aktivierung.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = [], echo_slot: int = -1) -> TakeReport:
	var gold_payout := 2 if charm_ids.has(Charm.GOLDSMITH) else 1
	var edge_gold_payout := 2 if charm_ids.has(Charm.FRAME_GILDER) else 1
	var bone_growth := 2 if charm_ids.has(Charm.BONE_GLUE) else 1
	var glass_shrinks := not charm_ids.has(Charm.GLASSBLOWER_LUNG)
	var report := TakeReport.new()
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		# Retrigger prüft den VERWANDELTEN Wert - wie in der Wertung.
		var shown := CharmEffects.transform_value(defs[i].faces[face], charm_ids)
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids, shown, echo_slot)

		if face_material == DieMaterial.GOLD:
			report.money += gold_payout * effect_count
		if edge_material == DieMaterial.GOLD:
			report.money += edge_gold_payout * effect_count

		var growth := 0
		if face_material == DieMaterial.BONE:
			growth += bone_growth * effect_count
		if edge_material == DieMaterial.BONE:
			growth += bone_growth * effect_count
		if growth > 0:
			defs[i].faces[face] += growth
			report.grown.append(i)

		var shrink_steps := 0
		if glass_shrinks:
			shrink_steps = (int(face_material == DieMaterial.GLASS) + int(edge_material == DieMaterial.GLASS)) * effect_count
		var shrunk_any := false
		for step in shrink_steps:
			if defs[i].faces[face] > EtchingEffects.MIN_FACE_VALUE:
				defs[i].faces[face] -= 1
				shrunk_any = true
		if shrunk_any:
			report.shrunk.append(i)
	return report
