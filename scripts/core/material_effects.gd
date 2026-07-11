class_name MaterialEffects
## Reine Wirkung der Seiten-Materialien (siehe DieMaterial) - analog zu
## CharmEffects: keine Nodes, nur Rechnen. Materialien wirken NUR auf Seiten,
## die oben liegen UND zur gewerteten Kombination gehören (participating, siehe
## DiceScoring.participating_indices) - genau wie der Basiswert selbst zählt.
##
## Zwei Arten von Wirkung, zwei Aufrufpunkte:
## - Wertungs-Boni (base_bonus/mult_bonus): reine Mathematik, von DiceScoring
##   in die Punktformel eingerechnet - zählen damit auch in der Live-Vorschau
##   und im Farkle-Vergleich.
## - Nehmen-Effekte (apply_take_effects): Nebenwirkungen (Geld, dauerhafte
##   Seitenänderung), die genau EINMAL beim tatsächlichen Nehmen feuern -
##   gerufen von scene_root, nie aus der Vorschau. Verwirft ein Farkle die
##   Hand, feuern sie nicht.
##
## values/materials sind parallele Arrays je Wurf-Slot (materials[i] = Material
## der oben liegenden Seite von Slot i, siehe scene_root._rolled_materials).

## Bericht der Nehmen-Effekte - was die UI anzeigen soll (Geld-Popup, welche
## Slots gewachsen/geschrumpft sind).
class TakeReport:
	extends RefCounted

	var money: int = 0  # Gold: +$1 je beteiligter Gold-Seite
	var grown: Array[int] = []  # Slot-Indizes, deren Seite +1 gewachsen ist (Knochen)
	var shrunk: Array[int] = []  # Slot-Indizes, deren Seite −1 geschrumpft ist (Glas)

## Zusätzliche Augen der beteiligten Material-Seiten, VOR dem Multiplikator:
## Bernstein +20 fest; Quecksilber zählt den (charm-angepassten) Augenwert der
## Seite ein zweites Mal - beides addiert sich zum Basiswert der Kombination.
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String]) -> int:
	var bonus := 0
	for i in participating:
		if i >= materials.size():
			continue
		match materials[i]:
			DieMaterial.AMBER:
				bonus += 20
			DieMaterial.MERCURY:
				bonus += CharmEffects.eye_value(values[i], charm_ids)
	return bonus

## Zusätzlicher Kombinations-Multiplikator der beteiligten Material-Seiten:
## Rubin +4 fest; Glas + rohe Augenzahl der Seite (je höher die Seite, desto
## stärker - und desto mehr hat sie beim Schrumpfen zu verlieren).
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int]) -> int:
	var bonus := 0
	for i in participating:
		if i >= materials.size():
			continue
		match materials[i]:
			DieMaterial.RUBY:
				bonus += 4
			DieMaterial.GLASS:
				bonus += values[i]
	return bonus

## Führt die Nehmen-Effekte der beteiligten Material-Seiten aus - mutiert die
## faces der betroffenen Würfel DIREKT (wie EtchingEffects; die Änderung ist
## dauerhaft, da die Pool-Würfel dieselben Instanzen sind) und liefert einen
## Bericht für die UI. Gold zahlt +$1; Knochen wächst +1 (nach oben offen, wie
## Überzahlen); Glas schrumpft −1, aber nie unter MIN_FACE_VALUE.
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int]) -> TakeReport:
	var report := TakeReport.new()
	for i in participating:
		if i >= materials.size() or i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		match materials[i]:
			DieMaterial.GOLD:
				report.money += 1
			DieMaterial.BONE:
				defs[i].faces[face] += 1
				report.grown.append(i)
			DieMaterial.GLASS:
				if defs[i].faces[face] > EtchingEffects.MIN_FACE_VALUE:
					defs[i].faces[face] -= 1
					report.shrunk.append(i)
	return report
