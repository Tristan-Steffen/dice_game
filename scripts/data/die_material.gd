class_name DieMaterial
extends Resource
## Datensatz eines Materials (Veredelung einer Würfelseite bzw. der Kanten).
## Anzeige-Infos hier, Wirkung löst MaterialEffects über die id auf; die
## Gravur-id der Material-Gravuren IST die Material-id.

# --- Material-ids (Single Source of Truth) ---
const RUBY := "ruby"          # +4 Mult
const AMBER := "amber"        # +20 Augen
const GOLD := "gold"          # +$1 beim Nehmen (Kanten: je Wurf)
const BONE := "bone"          # Seite wächst +1 beim Nehmen
const MERCURY := "mercury"    # Retrigger: Würfel aktiviert sich doppelt
const GLASS := "glass"        # Mult += Augen, Seite schrumpft −1 beim Nehmen

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var edge_description: String = ""  # Wirkung als Kanten-Material
## Körperfarbe der Seite - bewusst hell genug für die dunkle Augenzahl.
@export var tint: Color = Color.WHITE

static func _make(material_id: String, name: String, desc: String, edge_desc: String, face_tint: Color) -> DieMaterial:
	var material := DieMaterial.new()
	material.id = material_id
	material.display_name = name
	material.description = desc
	material.edge_description = edge_desc
	material.tint = face_tint
	return material

static func ruby() -> DieMaterial:
	return _make(RUBY, "Rubin",
		"+4 Mult, wenn diese Seite in der Kombination liegt.",
		"+4 Mult, wenn dieser Würfel in der Kombination liegt.",
		Color(0.82, 0.16, 0.26))

static func amber() -> DieMaterial:
	return _make(AMBER, "Bernstein",
		"+20 Augen beim Zählen, wenn diese Seite in der Kombination liegt.",
		"+20 Augen beim Zählen, wenn dieser Würfel in der Kombination liegt.",
		Color(0.88, 0.5, 0.11))

static func gold() -> DieMaterial:
	return _make(GOLD, "Gold",
		"+$1, wenn diese Seite in der genommenen Kombination liegt.",
		"+$1 bei jedem Wurf dieses Würfels.",
		Color(0.92, 0.74, 0.1))

static func bone() -> DieMaterial:
	return _make(BONE, "Knochen",
		"Diese Seite wächst dauerhaft +1, wenn sie in der genommenen Kombination liegt.",
		"Die oben liegende Seite wächst dauerhaft +1, wenn der Würfel in der genommenen Kombination liegt.",
		Color(0.76, 0.69, 0.5))

static func mercury() -> DieMaterial:
	return _make(MERCURY, "Quecksilber",
		"Der Würfel aktiviert sich doppelt, wenn diese Seite in der Kombination liegt: Augen und Material-Effekte zählen zweimal.",
		"Der Würfel aktiviert sich doppelt, wenn er in der Kombination liegt - liegt zusätzlich eine Quecksilber-Seite oben, vierfach.",
		Color(0.5, 0.58, 0.7))

static func glass() -> DieMaterial:
	return _make(GLASS, "Glas",
		"Mult += Augen dieser Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		"Mult += Augen der oben liegenden Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		Color(0.3, 0.66, 0.78))

## Kanonische Registrierung aller Materialien.
static func all() -> Array[DieMaterial]:
	return [ruby(), amber(), gold(), bone(), mercury(), glass()]

static func by_id(material_id: String) -> DieMaterial:
	for material in all():
		if material.id == material_id:
			return material
	return null

static func is_valid_id(material_id: String) -> bool:
	return by_id(material_id) != null

## Körperfarbe zur id - Weiß bei NONE/unbekannt (kein Sonderfall in der Anzeige).
static func tint_for(material_id: String) -> Color:
	var material := by_id(material_id)
	return material.tint if material != null else Color.WHITE

# Oberflächen-Texturen: helle, fast farblose Muster; die Materialfarbe liefert
# tint_for (Albedo = Textur × Tint). Konvention: Dateiname = Material-id.
const DIE_TEXTURE_DIR := "res://assets/textures/dice/"
const BASE_TEXTURE_ID := "dice_base"

static var _die_textures := {}  # Textur-id -> Texture2D oder null (Cache)

## Oberflächen-Textur zur id (""/unbekannt = Basis-Textur); null, falls die Datei fehlt.
static func die_texture_for(material_id: String) -> Texture2D:
	var texture_id := material_id if is_valid_id(material_id) else BASE_TEXTURE_ID
	if not _die_textures.has(texture_id):
		var path := DIE_TEXTURE_DIR + texture_id + ".png"
		_die_textures[texture_id] = load(path) if ResourceLoader.exists(path) else null
	return _die_textures[texture_id]
