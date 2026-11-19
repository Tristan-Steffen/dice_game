class_name DieMaterial
extends Resource
## Datensatz eines Materials (Belegung EINER Würfelseite).
## Anzeige-Infos hier, Wirkung löst MaterialEffects über die id auf; die
## Gravur-id der Material-Gravuren IST die Material-id.

# --- Material-ids (Single Source of Truth) ---
const RUBY := "ruby"          # +4 Mult
const AMBER := "amber"        # +20 Basispunkte + Augensumme
const GOLD := "gold"          # +$3 beim Nehmen
const BONE := "bone"          # Seite wächst +2 beim Nehmen
const GLASS := "glass"        # Mult += Augen (max 6), Seite schrumpft −1 beim Nehmen
const COPPER := "copper"      # +1 ⚡ beim Nehmen; Überlauf zahlt bar

const NONE := ""

## Zustand eines Seiten-Materials: 0 = keins, 1 = normal, 2 = veredelt. Mehr gibt
## es nicht - veredelt ist ein Zustand, keine Leiter.
const MAX_LEVEL := 2

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Kurzwirkung fürs Grube-Hover-Feld ("+20 Basispunkte").
@export var short: String = ""
## Veredelter Zustand; der normale steht in short/description.
@export var short_doped: String = ""
@export var description_doped: String = ""
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

## --- Die VEREDELUNG: das Material GLÜHT -----------------------------------------
## Spieler-Wahl 2026-11-19: veredelt leuchtet die Seite satt in ihrer eigenen
## Farbe, Edelmetall fasst nur zwei Ecken (Shader
## die_dope_mount). Die Werte hier sind die EINE Quelle dieses Aussehens.
@export var refined_color: Color = Color.WHITE
## Eigenlicht der Fläche; um 1 blüht der Kern leicht, der Rand nicht.
@export var refined_glow: float = 0.95
@export var refined_alpha: float = 1.0

static func _make(material_id: String, name: String, desc: String, face_tint: Color) -> DieMaterial:
	var material := DieMaterial.new()
	material.id = material_id
	material.display_name = name
	material.description = desc
	material.tint = face_tint
	return material

static func ruby() -> DieMaterial:
	var m := _make(RUBY, "Rubin",
		"+4 Mult, wenn diese Seite in der Kombination liegt.",
		Color(0.82, 0.16, 0.26))
	m.surface_color = Color(0.5, 0.07, 0.14)  # tiefer Edelstein, Facetten glitzern
	m.metallic = 0.15
	m.roughness = 0.08
	m.glow = 0.5
	m.refined_color = Color(1.0, 0.08, 0.22)
	m.short = "+4 Mult"
	m.short_doped = "Krit ×2"
	m.description_doped = "Krit ×2 auf den Mult, statt zu addieren."
	return m

static func amber() -> DieMaterial:
	var m := _make(AMBER, "Bernstein",
		"+20 Basispunkte plus die Augensumme des Würfels, wenn diese Seite in der Kombination liegt.",
		Color(0.88, 0.5, 0.11))
	m.surface_color = Color(0.8, 0.45, 0.14)  # Harz glüht von innen (Textur: Mitte hell)
	m.roughness = 0.35
	m.glow = 1.1
	m.refined_color = Color(1.0, 0.56, 0.0)
	m.short = "+20 Basis +Augensumme"
	m.short_doped = "5 × Augensumme"
	m.description_doped = "Die fünffache Augensumme des Würfels - ohne festen Zuschlag."
	return m

static func gold() -> DieMaterial:
	var m := _make(GOLD, "Gold",
		"+$3, wenn diese Seite in der genommenen Kombination liegt.",
		Color(0.92, 0.74, 0.1))
	# Metall spiegelt statt glühen; ohne Sky-Radiance (Ambient-only-Env) macht
	# volles metallic die Fläche schwarz - darum teil-metallisch + Restwärme.
	m.surface_color = Color(1.0, 0.82, 0.3)
	m.metallic = 0.6
	m.roughness = 0.14
	m.glow = 0.26
	m.refined_color = Color(1.0, 0.82, 0.0)
	m.short = "+$3"
	m.short_doped = "+$7 +$1 je Gold-Seite"
	m.description_doped = "+$7, dazu +$1 je ausgelöster Gold-Seite dieser Nahme."
	return m

static func bone() -> DieMaterial:
	var m := _make(BONE, "Knochen",
		"Diese Seite wächst dauerhaft +2, wenn sie in der genommenen Kombination liegt.",
		Color(0.76, 0.69, 0.5))
	m.surface_color = Color(0.82, 0.76, 0.6)  # tot-matt: normal das EINZIGE Material ohne Leuchten
	m.roughness = 0.95
	m.glow = 0.0
	# Veredelt glüht auch Knochen: warmes, helles Elfenbein statt mehr Farbe.
	m.refined_color = Color(1.0, 0.94, 0.80)
	m.refined_glow = 0.85
	m.short = "Seite wächst +2"
	m.short_doped = "Seite wächst +10 / +20 %"
	m.description_doped = "Die Seite wächst um 10 oder 20 %, je nachdem was mehr ist."
	return m

static func glass() -> DieMaterial:
	var m := _make(GLASS, "Glas",
		"Mult += Augen dieser Seite, höchstens 6; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		Color(0.3, 0.66, 0.78))
	m.surface_color = Color(0.62, 0.8, 0.86)  # durchsichtig: das Würfelinnere scheint durch
	m.roughness = 0.05
	m.glow = 0.3
	m.alpha = 0.42
	# Dichter als die glatte Seite: durch sie hätte die Glut keinen Grund.
	m.refined_color = Color(0.22, 0.80, 1.0)
	m.refined_alpha = 0.78
	m.short = "Mult += Augen (max 6)"
	m.short_doped = "Krit ×Augen/2"
	m.description_doped = "Krit ×(Augen/2), statt zu addieren; beim Nehmen halbiert sich die Seite."
	return m

static func copper() -> DieMaterial:
	var m := _make(COPPER, "Kupfer",
		"+1 ⚡, wenn diese Seite in der genommenen Kombination liegt.",
		Color(0.86, 0.47, 0.24))
	# WARM, nicht grünspan-cyan (Spieler-Entscheid 2026-10-25): die Seite wechselte
	# sonst beim Veredeln die Farbe. Seine Wirkung
	# trägt jetzt das ⚡ im Kurztext, nicht mehr der Farbton.
	m.surface_color = Color(0.72, 0.35, 0.17)
	m.metallic = 0.55
	m.roughness = 0.18
	m.glow = 0.42
	# Röter und dunkler als Bernstein, nie Energie-Cyan - das gehört den Runen.
	m.refined_color = Color(0.86, 0.28, 0.14)
	m.short = "+1 ⚡"
	m.short_doped = "+2 ⚡"
	m.description_doped = "+2 ⚡; was über den Speicher hinausgeht, zahlt $2 je ⚡."
	return m

## Kanonische Registrierung aller ERWERBBAREN Materialien - jede Ziehung, jede
## Gravur und jeder Würfelkauf rollt aus dieser Liste. GENAU SECHS: eine je Seite
## eines Würfels, und genau so weit reicht ein Material-Prägenetz.
static func all() -> Array[DieMaterial]:
	return [ruby(), amber(), gold(), bone(), glass(), copper()]

## Einmal gebaut: der Katalog-Neubau je Abfrage kostete ~30× pro apply_definition
## und war der halbe Ruckler beim Würfeln. Die Records sind schreibgeschützt.
static var _by_id := {}

static func by_id(material_id: String) -> DieMaterial:
	if _by_id.is_empty():
		for material in all():
			_by_id[material.id] = material
	return _by_id.get(material_id)

static func is_valid_id(material_id: String) -> bool:
	return by_id(material_id) != null

## Restsättigungs-Schrumpf der Veredelung: s' = 1 − (1 − s) × k. Ein glattes
## Multiplizieren ginge nicht - Rubin liegt schon bei S≈0.81 und wäre sofort am
## Anschlag, Knochen bei S≈0.34 und käme kaum vom Fleck.
const LEVEL_SATURATION := {2: 0.53}
## Kleiner Hellwert-Zuschlag, damit "satter" nie als "matschiger" liest. Bewusst
## klein: die Veredelung ist ein Signal aus Farbreinheit, nie aus Helligkeit.
const LEVEL_VALUE := {2: 1.08}

## Sättigt eine Farbe auf den veredelten Zustand. Normal gibt sie UNVERÄNDERT
## zurück - der Normalfall kündigt sich nie an.
static func saturated(color: Color, level: int) -> Color:
	if level <= 1 or not LEVEL_SATURATION.has(level):
		return color
	var result := color
	result.s = clampf(1.0 - (1.0 - color.s) * float(LEVEL_SATURATION[level]), 0.0, 1.0)
	result.v = clampf(color.v * float(LEVEL_VALUE[level]), 0.0, 1.0)
	return result

## Körperfarbe zur id - Weiß bei NONE/unbekannt (kein Sonderfall in der Anzeige).
## level gilt für die Farbe der SEITE; ohne Angabe bleibt jeder Aufrufer normal,
## also exakt auf der Farbe von vorher.
static func tint_for(material_id: String, level := 1) -> Color:
	var material := by_id(material_id)
	return saturated(material.tint, level) if material != null else Color.WHITE

## Kurzwirkung des Zustands; der normale steht in short/description.
func short_for(level: int) -> String:
	return short_doped if level >= MAX_LEVEL else short

func description_for(level: int) -> String:
	return description_doped if level >= MAX_LEVEL else description

## Kurz-Erklärzeile einer Seite fürs Hover-Feld ("" ohne Material): «Name»: Wirkung.
## Veredelt nennt sich im Namen, normal kündigt sich nie an.
static func face_hint(material_id: String, level := 1) -> String:
	var material := by_id(material_id)
	if material == null:
		return ""
	if level >= MAX_LEVEL:
		return "%s (veredelt): %s" % [material.display_name, material.short_doped]
	return "%s: %s" % [material.display_name, material.short]

# Oberflächen-Texturen: helle, fast farblose Muster; die Materialfarbe liefert
# tint_for (Albedo = Textur × Tint). Konvention: Dateiname = Material-id.
const DIE_TEXTURE_DIR := "res://assets/textures/dice/"
const BASE_TEXTURE_ID := "dice_base"

static var _die_textures := {}  # Textur-id -> Texture2D oder null (Cache)

## Oberflächen-Textur zur id (""/unbekannt = Basis-Textur); null, falls die Datei fehlt.
static func die_texture_for(material_id: String) -> Texture2D:
	var texture_id := material_id if is_valid_id(material_id) else BASE_TEXTURE_ID
	var texture := _load_die_texture(texture_id)
	# Fehlt die Materialtextur, trägt die Basis - eine musterlose Seite läse sich
	# wie gar kein Material.
	return texture if texture != null else _load_die_texture(BASE_TEXTURE_ID)

## Normal-Map zur id (Konvention <id>_n.png); null, wenn das Material keine hat.
static func die_normal_for(material_id: String) -> Texture2D:
	if not is_valid_id(material_id):
		return null
	return _load_die_texture(material_id + "_n")

static func _load_die_texture(texture_id: String) -> Texture2D:
	if not _die_textures.has(texture_id):
		var path := DIE_TEXTURE_DIR + texture_id + ".png"
		_die_textures[texture_id] = load(path) if ResourceLoader.exists(path) else null
	return _die_textures[texture_id]
