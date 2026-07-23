class_name DieMaterial
extends Resource
## Datensatz eines Materials (Veredelung einer Würfelseite bzw. der Kanten).
## Anzeige-Infos hier, Wirkung löst MaterialEffects über die id auf; die
## Gravur-id der Material-Gravuren IST die Material-id.

# --- Material-ids (Single Source of Truth) ---
const RUBY := "ruby"          # +4 Mult
const AMBER := "amber"        # +20 Basispunkte
const GOLD := "gold"          # +$3 beim Nehmen
const BONE := "bone"          # Seite wächst +1 beim Nehmen
const MERCURY := "mercury"    # Retrigger: Würfel aktiviert sich doppelt
const GLASS := "glass"        # Mult += Augen, Seite schrumpft −1 beim Nehmen

const NONE := ""

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var edge_description: String = ""  # Wirkung als Kanten-Material
## Kurzwirkung fürs Grube-Hover-Feld ("+20 Basispunkte"); edge_short als Kante.
@export var short: String = ""
@export var edge_short: String = ""
## Körperfarbe der Seite - bewusst hell genug für die dunkle Augenzahl.
@export var tint: Color = Color.WHITE

## Shading-Profil: jedes Material bricht die dunkle Glas-Regel auf seine Art
## (Gold spiegelt, Bernstein glüht, Knochen bleibt tot-matt) - so trägt die
## Oberfläche die Identität, nicht nur der Farbton. Wertet DieFaceDisplay aus.
@export var surface_color: Color = Color.WHITE  # echte Albedo der Einlage
@export var metallic: float = 0.0
@export var roughness: float = 0.3
@export var glow: float = 0.6       # Emissionsstärke (× tint)
@export var alpha: float = 1.0      # < 1: durchsichtige Seite (Glas)
@export var flow_speed: float = 0.0 # UV-Drift/s - Quecksilber fließt

static func _make(material_id: String, name: String, desc: String, edge_desc: String, face_tint: Color) -> DieMaterial:
	var material := DieMaterial.new()
	material.id = material_id
	material.display_name = name
	material.description = desc
	material.edge_description = edge_desc
	material.tint = face_tint
	return material

static func ruby() -> DieMaterial:
	var m := _make(RUBY, "Rubin",
		"+4 Mult, wenn diese Seite in der Kombination liegt.",
		"+4 Mult, wenn dieser Würfel in der Kombination liegt.",
		Color(0.82, 0.16, 0.26))
	m.surface_color = Color(0.5, 0.07, 0.14)  # tiefer Edelstein, Facetten glitzern
	m.metallic = 0.15
	m.roughness = 0.08
	m.glow = 0.5
	m.short = "+4 Mult"
	m.edge_short = "+4 Mult"
	return m

static func amber() -> DieMaterial:
	var m := _make(AMBER, "Bernstein",
		"+20 Basispunkte, wenn diese Seite in der Kombination liegt.",
		"+20 Basispunkte, wenn dieser Würfel in der Kombination liegt.",
		Color(0.88, 0.5, 0.11))
	m.surface_color = Color(0.8, 0.45, 0.14)  # Harz glüht von innen (Textur: Mitte hell)
	m.roughness = 0.35
	m.glow = 1.1
	m.short = "+20 Basispunkte"
	m.edge_short = "+20 Basispunkte"
	return m

static func gold() -> DieMaterial:
	var m := _make(GOLD, "Gold",
		"+$3, wenn diese Seite in der genommenen Kombination liegt.",
		"+$3, wenn dieser Würfel in der genommenen Kombination liegt.",
		Color(0.92, 0.74, 0.1))
	# Metall spiegelt statt glühen; ohne Sky-Radiance (Ambient-only-Env) macht
	# volles metallic die Fläche schwarz - darum teil-metallisch + Restwärme.
	m.surface_color = Color(1.0, 0.82, 0.3)
	m.metallic = 0.6
	m.roughness = 0.14
	m.glow = 0.26
	m.short = "+$3"
	m.edge_short = "+$3"
	return m

static func bone() -> DieMaterial:
	var m := _make(BONE, "Knochen",
		"Diese Seite wächst dauerhaft +1, wenn sie in der genommenen Kombination liegt.",
		"Die oben liegende Seite wächst dauerhaft +1, wenn der Würfel in der genommenen Kombination liegt.",
		Color(0.76, 0.69, 0.5))
	m.surface_color = Color(0.82, 0.76, 0.6)  # tot-matt: das EINZIGE Material ohne Leuchten
	m.roughness = 0.95
	m.glow = 0.0
	m.short = "Seite wächst +1"
	m.edge_short = "obere Seite wächst +1"
	return m

static func mercury() -> DieMaterial:
	var m := _make(MERCURY, "Quecksilber",
		"Der Würfel aktiviert sich doppelt, wenn diese Seite in der Kombination liegt: Augen und Material-Effekte zählen zweimal.",
		"Der Würfel aktiviert sich doppelt, wenn er in der Kombination liegt.",
		Color(0.5, 0.58, 0.7))
	m.surface_color = Color(0.78, 0.82, 0.88)  # kaltes Flüssigmetall, Oberfläche fließt
	m.metallic = 0.6
	m.roughness = 0.1
	m.glow = 0.22
	m.flow_speed = 0.05
	m.short = "doppelte Auslösung"
	m.edge_short = "doppelte Auslösung"
	return m

static func glass() -> DieMaterial:
	var m := _make(GLASS, "Glas",
		"Mult += Augen dieser Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		"Mult += Augen der oben liegenden Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		Color(0.3, 0.66, 0.78))
	m.surface_color = Color(0.62, 0.8, 0.86)  # durchsichtig: das Würfelinnere scheint durch
	m.roughness = 0.05
	m.glow = 0.3
	m.alpha = 0.42
	m.short = "Mult += Augen"
	m.edge_short = "Mult += Augen"
	return m

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

## Kurz-Erklärzeile einer Seite fürs Hover-Feld ("" ohne Material): «Name»: Wirkung.
static func face_hint(material_id: String) -> String:
	var material := by_id(material_id)
	return "%s: %s" % [material.display_name, material.short] if material != null else ""

## Kurz-Erklärzeile eines Kanten-Materials ("" ohne): «Name» (Kanten): Wirkung.
static func edge_hint(material_id: String) -> String:
	var material := by_id(material_id)
	return "%s (Kanten): %s" % [material.display_name, material.edge_short] if material != null else ""

# Oberflächen-Texturen: helle, fast farblose Muster; die Materialfarbe liefert
# tint_for (Albedo = Textur × Tint). Konvention: Dateiname = Material-id.
const DIE_TEXTURE_DIR := "res://assets/textures/dice/"
const BASE_TEXTURE_ID := "dice_base"

static var _die_textures := {}  # Textur-id -> Texture2D oder null (Cache)

## Oberflächen-Textur zur id (""/unbekannt = Basis-Textur); null, falls die Datei fehlt.
static func die_texture_for(material_id: String) -> Texture2D:
	var texture_id := material_id if is_valid_id(material_id) else BASE_TEXTURE_ID
	return _load_die_texture(texture_id)

## Normal-Map zur id (Konvention <id>_n.png); null, wenn das Material keine hat.
static func die_normal_for(material_id: String) -> Texture2D:
	if not is_valid_id(material_id):
		return null
	return _load_die_texture(material_id + "_n")

## Alpha-Rahmenlinie der Material-Seiten (materialunabhängig, Tint zur Laufzeit).
static func face_frame_texture() -> Texture2D:
	return _load_die_texture("face_frame")

static func _load_die_texture(texture_id: String) -> Texture2D:
	if not _die_textures.has(texture_id):
		var path := DIE_TEXTURE_DIR + texture_id + ".png"
		_die_textures[texture_id] = load(path) if ResourceLoader.exists(path) else null
	return _die_textures[texture_id]
