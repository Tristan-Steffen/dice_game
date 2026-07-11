class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial) - analog zu CharmEffects:
## keine Nodes, nur Rechnen. Zwei Träger:
## - SEITEN-Material (materials[i], siehe DieDefinition.materials): wirkt nur,
##   wenn genau diese Seite oben liegt UND zur gewerteten Kombination gehört
##   (participating, siehe DiceScoring.participating_indices).
## - KANTEN-Material (edge_materials[i], siehe DieDefinition.edge_material):
##   wirkt für den GANZEN Würfel, egal welche Seite oben liegt - sobald der
##   Würfel zur Kombination gehört. Gleiche Grundwirkung wie das Seiten-Material;
##   tragen Seite UND Kanten dasselbe Material, stapeln beide (Quecksilber
##   multiplikativ: Kanten ×2 und Seite ×2 = vierfach).
##
## Zwei Arten von Wirkung, drei Aufrufpunkte:
## - Wertungs-Boni (base_bonus/mult_bonus): reine Mathematik, von DiceScoring
##   in die Punktformel eingerechnet - zählen damit auch in der Live-Vorschau
##   und im Farkle-Vergleich.
## - Nehmen-Effekte (apply_take_effects): Nebenwirkungen (Geld, dauerhafte
##   Seitenänderung), die genau EINMAL beim tatsächlichen Nehmen feuern -
##   gerufen von scene_root, nie aus der Vorschau. Verwirft ein Farkle die
##   Hand, feuern sie nicht.
## - Wurf-Effekte (roll_money): Gold-KANTEN zahlen bei jedem Wurf des Würfels
##   (nicht erst beim Nehmen) - gerufen von scene_root, sobald ein Wurf liegt.
##
## values/materials/edge_materials sind parallele Arrays je Wurf-Slot
## (materials[i] = Material der oben liegenden Seite von Slot i, siehe
## scene_root._rolled_materials; edge_materials[i] = Kanten-Material des
## Würfels in Slot i, siehe scene_root._edge_materials).

## Bericht der Nehmen-Effekte - was die UI anzeigen soll (Geld-Popup, welche
## Slots gewachsen/geschrumpft sind).
class TakeReport:
	extends RefCounted

	var money: int = 0  # Gold-Seite: +$1 je beteiligter Gold-Seite
	var grown: Array[int] = []  # Slot-Indizes, deren Seite gewachsen ist (Knochen)
	var shrunk: Array[int] = []  # Slot-Indizes, deren Seite geschrumpft ist (Glas)

## Zusätzliche Augen der beteiligten Material-Träger, VOR dem Multiplikator:
## Bernstein +20 fest (Seite und/oder Kanten); Quecksilber zählt den
## (charm-angepassten) Augenwert erneut - Seite ×2, Kanten ×2, beides ×4
## (bonus = Wert × (Faktor − 1), der Grundwert steckt schon im Basiswert).
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], edge_materials: Array[String] = []) -> int:
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		if face_material == DieMaterial.AMBER:
			bonus += 20
		if edge_material == DieMaterial.AMBER:
			bonus += 20
		var factor := 1
		if face_material == DieMaterial.MERCURY:
			factor *= 2
		if edge_material == DieMaterial.MERCURY:
			factor *= 2
		if factor > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (factor - 1)
	return bonus

## Zusätzlicher Kombinations-Multiplikator der beteiligten Material-Träger:
## Rubin +4 fest (Seite und/oder Kanten); Glas + rohe Augenzahl der oben
## liegenden Seite (je höher die Seite, desto stärker - und desto mehr hat
## sie beim Schrumpfen zu verlieren).
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = []) -> int:
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		if face_material == DieMaterial.RUBY:
			bonus += 4
		if edge_material == DieMaterial.RUBY:
			bonus += 4
		if face_material == DieMaterial.GLASS:
			bonus += values[i]
		if edge_material == DieMaterial.GLASS:
			bonus += values[i]
	return bonus

## Führt die Nehmen-Effekte der beteiligten Material-Träger aus - mutiert die
## faces der betroffenen Würfel DIREKT (wie EtchingEffects; die Änderung ist
## dauerhaft, da die Pool-Würfel dieselben Instanzen sind) und liefert einen
## Bericht für die UI. Gold-SEITE zahlt +$1 (Gold-Kanten zahlen stattdessen je
## Wurf, siehe roll_money); Knochen wächst die oben liegende Seite +1 je Träger
## (nach oben offen, wie Überzahlen); Glas schrumpft sie −1 je Träger, aber nie
## unter MIN_FACE_VALUE.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = []) -> TakeReport:
	var report := TakeReport.new()
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""

		if face_material == DieMaterial.GOLD:
			report.money += 1

		var growth := 0
		if face_material == DieMaterial.BONE:
			growth += 1
		if edge_material == DieMaterial.BONE:
			growth += 1
		if growth > 0:
			defs[i].faces[face] += growth
			report.grown.append(i)

		var shrink_steps := int(face_material == DieMaterial.GLASS) + int(edge_material == DieMaterial.GLASS)
		var shrunk_any := false
		for step in shrink_steps:
			if defs[i].faces[face] > EtchingEffects.MIN_FACE_VALUE:
				defs[i].faces[face] -= 1
				shrunk_any = true
		if shrunk_any:
			report.shrunk.append(i)
	return report

## Geld der Gold-KANTEN für einen Wurf: +$1 je geworfenem Würfel mit
## Gold-Kanten (thrown = Slot-Indizes der tatsächlich geworfenen Würfel;
## geschützte, liegen gebliebene Würfel zahlen nicht). Zahlt bei JEDEM Wurf -
## auch wenn der Wurf danach farkelt.
static func roll_money(edge_materials: Array[String], thrown: Array[int]) -> int:
	var money := 0
	for i in thrown:
		if i < edge_materials.size() and edge_materials[i] == DieMaterial.GOLD:
			money += 1
	return money
