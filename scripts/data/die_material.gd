class_name DieMaterial
extends Resource
## Datensatz für ein Seiten-Material: eine Veredelung, die GENAU EINE Würfelseite
## trägt (wie Balatro-Kartenveredelungen - Gold, Glas, Mult). Aufbau wie
## Charm/Coupon: Anzeige-Infos hier, die eigentliche Wirkung zentral über die id
## aufgelöst (siehe MaterialEffects). Angebracht werden Materialien über
## Material-Coupons von den Coupon-Bögen (siehe Coupon.KIND_MATERIAL) in der
## Gravur-Station; die Coupon-id IST die Material-id.
##
## Ein Material wirkt nur, wenn seine Seite oben liegt UND zur genommenen
## Kombination gehört (siehe DiceScoring.participating_indices) - Wertungs-Boni
## (Rubin/Bernstein/Quecksilber/Glas-Mult) zählen schon in der Vorschau, die
## Nehmen-Effekte (Gold/Knochen/Glas-Schrumpfen) feuern genau einmal beim Nehmen
## (siehe MaterialEffects.apply_take_effects).

# --- Material-ids (Single Source of Truth; genutzt hier + MaterialEffects +
# als Coupon-ids der Material-Coupons, siehe Coupon) ---
const RUBY := "ruby"          # Rubin: +4 Mult
const AMBER := "amber"        # Bernstein: +20 Augen beim Zählen
const GOLD := "gold"          # Gold: +$1 beim Nehmen
const BONE := "bone"          # Knochen: Seite wächst +1 beim Nehmen
const MERCURY := "mercury"    # Quecksilber: Seite zählt doppelt
const GLASS := "glass"        # Glas: Mult += Augen der Seite, Seite schrumpft −1 beim Nehmen

## "Kein Material" - der Standardwert jeder Seite (siehe DieDefinition.materials).
const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Wirkung als KANTEN-Material (ganzer Würfel statt einer Seite, siehe
## DieDefinition.edge_material) - Grundlage der Kanten-Coupons (siehe
## Coupon.edge_coupon). Gleiche Grundidee wie description, wirkt aber egal,
## welche Seite oben liegt.
@export var edge_description: String = ""
## Körperfarbe der Seite mit diesem Material (siehe DieFaceDisplay) - bewusst
## helle Töne, damit die dunkle Augenzahl lesbar bleibt.
@export var tint: Color = Color.WHITE

static func _make(material_id: String, name: String, desc: String, edge_desc: String, face_tint: Color) -> DieMaterial:
	var material := DieMaterial.new()
	material.id = material_id
	material.display_name = name
	material.description = desc
	material.edge_description = edge_desc
	material.tint = face_tint
	return material

## Rubin: +4 Mult, wenn die Seite in der genommenen Kombination liegt.
static func ruby() -> DieMaterial:
	return _make(RUBY, "Rubin",
		"+4 Mult, wenn diese Seite in der Kombination liegt.",
		"+4 Mult, wenn dieser Würfel in der Kombination liegt.",
		Color(0.94, 0.45, 0.5))

## Bernstein: +20 Augen beim Zählen.
static func amber() -> DieMaterial:
	return _make(AMBER, "Bernstein",
		"+20 Augen beim Zählen, wenn diese Seite in der Kombination liegt.",
		"+20 Augen beim Zählen, wenn dieser Würfel in der Kombination liegt.",
		Color(1.0, 0.78, 0.42))

## Gold: +$1 beim Nehmen (als Kanten-Material: bei jedem Wurf).
static func gold() -> DieMaterial:
	return _make(GOLD, "Gold",
		"+$1, wenn diese Seite in der genommenen Kombination liegt.",
		"+$1 bei jedem Wurf dieses Würfels.",
		Color(1.0, 0.88, 0.45))

## Knochen: die Seite wächst beim Nehmen dauerhaft um +1.
static func bone() -> DieMaterial:
	return _make(BONE, "Knochen",
		"Diese Seite wächst dauerhaft +1, wenn sie in der genommenen Kombination liegt.",
		"Die oben liegende Seite wächst dauerhaft +1, wenn der Würfel in der genommenen Kombination liegt.",
		Color(0.93, 0.9, 0.78))

## Quecksilber: die Seite zählt doppelt (Kanten: der ganze Würfel).
static func mercury() -> DieMaterial:
	return _make(MERCURY, "Quecksilber",
		"Diese Seite zählt doppelt, wenn sie in der Kombination liegt.",
		"Dieser Würfel zählt doppelt - liegt zusätzlich eine Quecksilber-Seite oben, vierfach.",
		Color(0.78, 0.83, 0.92))

## Glas: Mult += Augen der Seite, danach schrumpft sie dauerhaft um −1.
static func glass() -> DieMaterial:
	return _make(GLASS, "Glas",
		"Mult += Augen dieser Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		"Mult += Augen der oben liegenden Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		Color(0.68, 0.88, 0.95))

## Alle existierenden Materialien (kanonische Registrierung) - Grundlage für die
## Material-Coupons (siehe Coupon.all). Ein neues Material wird hier eingehängt.
static func all() -> Array[DieMaterial]:
	return [ruby(), amber(), gold(), bone(), mercury(), glass()]

## Das Material zur id, oder null bei NONE/unbekannt.
static func by_id(material_id: String) -> DieMaterial:
	for material in all():
		if material.id == material_id:
			return material
	return null

## True, wenn material_id ein existierendes Material bezeichnet (nicht NONE).
static func is_valid_id(material_id: String) -> bool:
	return by_id(material_id) != null

## Körperfarbe für eine Seite mit material_id - Weiß bei NONE/unbekannt, damit
## die Anzeige (DieFaceDisplay) keinen Sonderfall braucht.
static func tint_for(material_id: String) -> Color:
	var material := by_id(material_id)
	return material.tint if material != null else Color.WHITE
