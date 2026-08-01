class_name DieMaterial
extends Resource
## Datensatz eines Materials (Veredelung EINER Würfelseite).
## Anzeige-Infos hier, Wirkung löst MaterialEffects über die id auf; die
## Gravur-id der Material-Gravuren IST die Material-id.

# --- Material-ids (Single Source of Truth) ---
const RUBY := "ruby"          # +4 Mult
const AMBER := "amber"        # +20 Basispunkte + Augensumme
const GOLD := "gold"          # +$3 beim Nehmen
const BONE := "bone"          # Seite wächst +1 beim Nehmen
const GLASS := "glass"        # Mult += Augen, Seite schrumpft −1 beim Nehmen

const NONE := ""

## Sättigung: jedes Seiten-Material steht auf Stufe I-III. Höher geht nicht -
## Stufe III ist das Ende der Leiter, nicht bloß die nächste Zahl.
const MAX_LEVEL := 3

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Kurzwirkung fürs Grube-Hover-Feld ("+20 Basispunkte").
@export var short: String = ""
## Stufen II/III; Stufe I steht in short/description.
@export var short_2: String = ""
@export var description_2: String = ""
@export var short_3: String = ""
@export var description_3: String = ""
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
	m.short = "+4 Mult"
	m.short_2 = "+10 Mult"
	m.description_2 = "+10 Mult statt +4."
	m.short_3 = "Krit ×2"
	m.description_3 = "Krit ×2 auf den Mult, statt zu addieren."
	return m

static func amber() -> DieMaterial:
	var m := _make(AMBER, "Bernstein",
		"+20 Basispunkte plus die Augensumme des Würfels, wenn diese Seite in der Kombination liegt.",
		Color(0.88, 0.5, 0.11))
	m.surface_color = Color(0.8, 0.45, 0.14)  # Harz glüht von innen (Textur: Mitte hell)
	m.roughness = 0.35
	m.glow = 1.1
	m.short = "+20 Basis +Augensumme"
	m.short_2 = "+50 Basis +Augensumme"
	m.description_2 = "+50 Basispunkte plus die Augensumme des Würfels."
	m.short_3 = "5 × Augensumme"
	m.description_3 = "Die fünffache Augensumme des Würfels - ohne festen Zuschlag."
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
	m.short = "+$3"
	m.short_2 = "+$7"
	m.description_2 = "+$7 statt +$3."
	m.short_3 = "+$7 +$1 je Gold-Seite"
	m.description_3 = "+$7, dazu +$1 je ausgelöster Gold-Seite dieser Nahme."
	return m

static func bone() -> DieMaterial:
	var m := _make(BONE, "Knochen",
		"Diese Seite wächst dauerhaft +1, wenn sie in der genommenen Kombination liegt.",
		Color(0.76, 0.69, 0.5))
	m.surface_color = Color(0.82, 0.76, 0.6)  # tot-matt: das EINZIGE Material ohne Leuchten
	m.roughness = 0.95
	m.glow = 0.0
	m.short = "Seite wächst +1"
	m.short_2 = "Seite wächst +3 / +10 %"
	m.description_2 = "Die Seite wächst um 3 oder 10 %, je nachdem was mehr ist."
	m.short_3 = "Seite wächst +3 / +20 %"
	m.description_3 = "Die Seite wächst um 3 oder 20 %, je nachdem was mehr ist."
	return m

static func glass() -> DieMaterial:
	var m := _make(GLASS, "Glas",
		"Mult += Augen dieser Seite; beim Nehmen schrumpft sie dauerhaft −1 (min. 1).",
		Color(0.3, 0.66, 0.78))
	m.surface_color = Color(0.62, 0.8, 0.86)  # durchsichtig: das Würfelinnere scheint durch
	m.roughness = 0.05
	m.glow = 0.3
	m.alpha = 0.42
	m.short = "Mult += Augen"
	m.short_2 = "Krit ×Augen"
	m.description_2 = "Krit ×Augen dieser Seite; beim Nehmen schrumpft sie um 5 oder 20 %."
	m.short_3 = "Mult += Augen, Krit ×Augen"
	m.description_3 = "Mult += Augen UND Krit ×Augen; beim Nehmen schrumpft sie um 5 oder 20 %."
	return m

## Kanonische Registrierung aller ERWERBBAREN Materialien - jede Ziehung, jede
## Gravur und jeder Würfelkauf rollt aus dieser Liste.
static func all() -> Array[DieMaterial]:
	return [ruby(), amber(), gold(), bone(), glass()]

static func by_id(material_id: String) -> DieMaterial:
	for material in all():
		if material.id == material_id:
			return material
	return null

static func is_valid_id(material_id: String) -> bool:
	return by_id(material_id) != null

## Restsättigungs-Schrumpf je Stufe: s' = 1 − (1 − s) × k. Ein glattes Multiplizieren
## ginge nicht - Rubin liegt schon bei S≈0.81 und wäre sofort am Anschlag, Knochen
## bei S≈0.34 und käme kaum vom Fleck. So schreiten BEIDE zweimal sichtbar:
## Rubin 0.81 → 0.86 → 0.90, Knochen 0.34 → 0.51 → 0.65.
const LEVEL_SATURATION := {2: 0.74, 3: 0.53}
## Kleiner Hellwert-Zuschlag, damit "satter" nie als "matschiger" liest. Bewusst
## klein: die Stufe ist ein Signal aus Farbreinheit, nie aus Helligkeit.
const LEVEL_VALUE := {2: 1.04, 3: 1.08}

## Sättigt eine Farbe auf die Materialstufe. Stufe 0/I gibt sie UNVERÄNDERT
## zurück - Stufe I ist der Normalfall und kündigt sich nie an.
static func saturated(color: Color, level: int) -> Color:
	if level <= 1 or not LEVEL_SATURATION.has(level):
		return color
	var result := color
	result.s = clampf(1.0 - (1.0 - color.s) * float(LEVEL_SATURATION[level]), 0.0, 1.0)
	result.v = clampf(color.v * float(LEVEL_VALUE[level]), 0.0, 1.0)
	return result

## Körperfarbe zur id - Weiß bei NONE/unbekannt (kein Sonderfall in der Anzeige).
## level gilt für die Farbe der SEITE; ohne Angabe bleibt jeder Aufrufer auf
## Stufe I, also exakt auf der Farbe von vorher.
static func tint_for(material_id: String, level := 1) -> Color:
	var material := by_id(material_id)
	return saturated(material.tint, level) if material != null else Color.WHITE

## Kurzwirkung der Stufe; Stufe I steht in short/description.
func short_for(level: int) -> String:
	match level:
		2:
			return short_2
		3:
			return short_3
	return short

func description_for(level: int) -> String:
	match level:
		2:
			return description_2
		3:
			return description_3
	return description

## Römische Stufenziffer für die Anzeige - Stufe I nennt sich nicht, sie ist der
## Normalfall.
static func level_roman(level: int) -> String:
	match level:
		2:
			return "II"
		3:
			return "III"
	return ""

## Kurz-Erklärzeile einer Seite fürs Hover-Feld ("" ohne Material): «Name»: Wirkung.
## Ab Stufe II trägt der Name die römische Ziffer.
static func face_hint(material_id: String, level := 1) -> String:
	var material := by_id(material_id)
	if material == null:
		return ""
	if level >= 2:
		return "%s %s: %s" % [material.display_name, level_roman(level), material.short_for(level)]
	return "%s: %s" % [material.display_name, material.short]

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
