class_name MaterialEffects
## Reine Wirkung der Materialien (siehe DieMaterial) - analog zu CharmEffects:
## keine Nodes, nur Rechnen. Zwei Träger:
## - SEITEN-Material (materials[i], siehe DieDefinition.materials): wirkt nur,
##   wenn genau diese Seite oben liegt UND zur gewerteten Kombination gehört
##   (participating, siehe DiceScoring.participating_indices).
## - KANTEN-Material (edge_materials[i], siehe DieDefinition.edge_material):
##   wirkt für den GANZEN Würfel, egal welche Seite oben liegt - sobald der
##   Würfel zur Kombination gehört. Gleiche Grundwirkung wie das Seiten-Material;
##   tragen Seite UND Kanten dasselbe Material, stapeln beide.
##
## Quecksilber ist ein RETRIGGER: der Würfel aktiviert sich doppelt (siehe
## activation_count). Jede Aktivierung zählt die Augen des Würfels UND feuert
## seine übrigen Material-Effekte (Bernstein/Rubin/Glas-Boni, Gold/Knochen/
## Glas-Nehmen-Effekte) erneut. Seite und Kanten stapeln multiplikativ
## (Kanten ×2 und Seite ×2 = vierfach); die Wurf-Effekte der Gold-Kanten
## (roll_money) zählen nicht als Aktivierung und bleiben unberührt.
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

## Wie oft sich der Würfel in Slot i aktiviert: 1 normal, ×2 je Quecksilber-
## Träger (Seite oben und/oder Kanten), mit Quecksilberdampf (siehe Charm)
## ×3 je Träger. Jede Aktivierung zählt Augen und Material-Effekte des
## Würfels erneut (siehe base_bonus/mult_bonus/apply_take_effects).
static func activation_count(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String]) -> int:
	var mercury_factor := 3 if charm_ids.has(Charm.MERCURY_VAPOR) else 2
	var count := 1
	if i < materials.size() and materials[i] == DieMaterial.MERCURY:
		count *= mercury_factor
	if i < edge_materials.size() and edge_materials[i] == DieMaterial.MERCURY:
		count *= mercury_factor
	return count

## Wie oft die MATERIAL-EFFEKTE des Würfels in Slot i feuern: die Aktivierungen
## (Quecksilber, siehe activation_count), zusätzlich ×2 durch die Legierung
## (siehe Charm.ALLOY), wenn der Würfel Material-Seite oben UND Kanten-Material
## trägt. Anders als Quecksilber verdoppelt die Legierung NUR die Effekte,
## nicht das Augen-Zählen (das bleibt an activation_count).
static func effect_activations(i: int, materials: Array[String], edge_materials: Array[String], charm_ids: Array[String]) -> int:
	var count := activation_count(i, materials, edge_materials, charm_ids)
	if charm_ids.has(Charm.ALLOY):
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		if face_material != "" and edge_material != "":
			count *= 2
	return count

## Zusätzliche Augen der beteiligten Material-Träger, VOR dem Multiplikator:
## Bernstein +20 fest (Seite und/oder Kanten), je Aktivierung; Quecksilber
## aktiviert den Würfel doppelt - die (charm-angepassten) Augen zählen je
## zusätzlicher Aktivierung erneut (bonus = Wert × (Aktivierungen − 1), der
## Grundwert steckt schon im Basiswert).
static func base_bonus(values: Array[int], materials: Array[String], participating: Array[int], charm_ids: Array[String], edge_materials: Array[String] = []) -> int:
	# Charm-Verstärker (siehe Charm/CharmEffects): Bernsteinzimmer hebt Bernstein
	# auf +50, Quecksilberdampf lässt Quecksilber dreifach statt doppelt aktivieren.
	var amber_value := 50 if charm_ids.has(Charm.AMBER_ROOM) else 20
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var activations := activation_count(i, materials, edge_materials, charm_ids)
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids)
		if face_material == DieMaterial.AMBER:
			bonus += amber_value * effect_count
		if edge_material == DieMaterial.AMBER:
			bonus += amber_value * effect_count
		if activations > 1:
			bonus += CharmEffects.eye_value(values[i], charm_ids) * (activations - 1)
	return bonus

## Zusätzlicher Kombinations-Multiplikator der beteiligten Material-Träger,
## je Aktivierung (Quecksilber verdoppelt, siehe activation_count):
## Rubin +4 fest (Seite und/oder Kanten); Glas + rohe Augenzahl der oben
## liegenden Seite (je höher die Seite, desto stärker - und desto mehr hat
## sie beim Schrumpfen zu verlieren).
static func mult_bonus(values: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = []) -> int:
	# Rubinschleifer (siehe CharmEffects) hebt Rubin auf +10 Mult.
	var ruby_value := 10 if charm_ids.has(Charm.RUBY_GRINDER) else 4
	var bonus := 0
	for i in participating:
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids)
		if face_material == DieMaterial.RUBY:
			bonus += ruby_value * effect_count
		if edge_material == DieMaterial.RUBY:
			bonus += ruby_value * effect_count
		if face_material == DieMaterial.GLASS:
			bonus += values[i] * effect_count
		if edge_material == DieMaterial.GLASS:
			bonus += values[i] * effect_count
	return bonus

## Führt die Nehmen-Effekte der beteiligten Material-Träger aus - mutiert die
## faces der betroffenen Würfel DIREKT (wie EtchingEffects; die Änderung ist
## dauerhaft, da die Pool-Würfel dieselben Instanzen sind) und liefert einen
## Bericht für die UI. Gold-SEITE zahlt +$1 (Gold-Kanten zahlen stattdessen je
## Wurf, siehe roll_money); Knochen wächst die oben liegende Seite +1 je Träger
## (nach oben offen, wie Überzahlen); Glas schrumpft sie −1 je Träger, aber nie
## unter MIN_FACE_VALUE. Alles je Aktivierung: Quecksilber am selben Würfel
## lässt diese Effekte doppelt feuern (siehe activation_count).
static func apply_take_effects(defs: Array[DieDefinition], face_indices: Array[int], materials: Array[String], participating: Array[int], edge_materials: Array[String] = [], charm_ids: Array[String] = []) -> TakeReport:
	# Charm-Verstärker (siehe CharmEffects): Goldschmied $2 je Gold-Seite,
	# Knochenleim +2 Wachstum, Glasbläserlunge schützt Glas bis min. 3.
	var gold_payout := 2 if charm_ids.has(Charm.GOLDSMITH) else 1
	var bone_growth := 2 if charm_ids.has(Charm.BONE_GLUE) else 1
	var glass_floor := 3 if charm_ids.has(Charm.GLASSBLOWER_LUNG) else EtchingEffects.MIN_FACE_VALUE
	var report := TakeReport.new()
	for i in participating:
		if i >= defs.size() or i >= face_indices.size():
			continue
		var face: int = face_indices[i]
		if face < 0:
			continue
		var face_material: String = materials[i] if i < materials.size() else ""
		var edge_material: String = edge_materials[i] if i < edge_materials.size() else ""
		var effect_count := effect_activations(i, materials, edge_materials, charm_ids)

		if face_material == DieMaterial.GOLD:
			report.money += gold_payout * effect_count

		var growth := 0
		if face_material == DieMaterial.BONE:
			growth += bone_growth * effect_count
		if edge_material == DieMaterial.BONE:
			growth += bone_growth * effect_count
		if growth > 0:
			defs[i].faces[face] += growth
			report.grown.append(i)

		var shrink_steps := (int(face_material == DieMaterial.GLASS) + int(edge_material == DieMaterial.GLASS)) * effect_count
		var shrunk_any := false
		for step in shrink_steps:
			if defs[i].faces[face] > glass_floor:
				defs[i].faces[face] -= 1
				shrunk_any = true
		if shrunk_any:
			report.shrunk.append(i)
	return report

## Geld der Gold-KANTEN für einen Wurf: +$1 je geworfenem Würfel mit
## Gold-Kanten (thrown = Slot-Indizes der tatsächlich geworfenen Würfel;
## geschützte, liegen gebliebene Würfel zahlen nicht). Zahlt bei JEDEM Wurf -
## auch wenn der Wurf danach farkelt.
static func roll_money(edge_materials: Array[String], thrown: Array[int], charm_ids: Array[String] = []) -> int:
	# Rahmenvergolder (siehe CharmEffects): Gold-Kanten zahlen $2 je Wurf.
	var per_die := 2 if charm_ids.has(Charm.FRAME_GILDER) else 1
	var money := 0
	for i in thrown:
		if i < edge_materials.size() and edge_materials[i] == DieMaterial.GOLD:
			money += per_die
	return money
