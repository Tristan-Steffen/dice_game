class_name Coupon
extends Resource
## Ein verbrauchbarer "Coupon" - kommt über Coupon-Bögen aus dem Shop (siehe
## CouponSheet/ShopController) und wird unbegrenzt gehortet. Aktuell sind alle
## Coupons Ätzungen (etchings), die die Seiten eines Würfels verändern; künftig
## kommen weitere kinds dazu (Materialien für einen ganzen Würfel, Sigille für
## eine Seite). Die eigentliche Wirkung wird - wie bei Charm/CharmEffects - über
## die id aufgelöst (siehe EtchingEffects); hier stehen nur die Anzeige-Infos.
##
## Die id ist einmal als Konstante definiert und überall darüber referenziert,
## damit ein Tippfehler ein Compilerfehler wird statt eines stillen No-ops.

enum Rarity { COMMON, UNCOMMON, RARE }

# kind eines Coupons: Ätzungen verändern die Augen eines Würfels (siehe
# EtchingEffects), Materialien belegen genau eine Seite mit einer Veredelung
# (siehe DieMaterial/MaterialEffects; die Coupon-id IST die Material-id),
# Kanten-Materialien veredeln den GANZEN Würfel (siehe
# DieDefinition.edge_material; Coupon-id = EDGE_PREFIX + Material-id).
const KIND_ETCHING := "etching"
const KIND_MATERIAL := "material"
const KIND_EDGE := "edge"

## Präfix der Kanten-Coupon-ids vor der Material-id ("edge_gold", ...) - damit
## kollidieren sie nie mit den Seiten-Material-Coupons (id = Material-id).
const EDGE_PREFIX := "edge_"

# --- Coupon-ids (Single Source of Truth; genutzt in coupon.gd + EtchingEffects) ---
const CHISEL := "chisel"
const TRANSPLANT := "transplant"
const GRINDSTONE := "grindstone"
const FINE_ENGRAVING := "fine_engraving"
const OVERCOUNT_ENGRAVING := "overcount_engraving"
const FILE_DOWN := "file_down"
const DOUBLE_NOTCH := "double_notch"
const AVERAGING := "averaging"
const CONNECT_UP := "connect_up"
const MIRROR := "mirror"
const IMPRINT := "imprint"
const STRAIGHTEN := "straighten"
const BLUEPRINT := "blueprint"

# Ordner der Coupon-Texturen (randlose Motive; Perforation/Rahmen zeichnet die
# Anzeige, siehe CouponSheetView / Obsidian "Coupon-Textur-Prompts").
# Konvention: Dateiname = Coupon-id (chisel.jpg, blueprint.jpg, ...) - ein
# neuer Coupon braucht keine Textur-Registrierung, nur die richtig benannte Datei.
const TEXTURE_DIR := "res://assets/textures/engravings/"

# Fläche (Breite × Höhe in Rasterzellen) je Coupon - die Fläche IST die Rarität
# (siehe Obsidian "02 Gravuren"). Bestimmt Platzbedarf auf dem Bogen und das
# Seitenverhältnis der Textur.
const FOOTPRINT := {
	CHISEL: Vector2i(3, 2),
	TRANSPLANT: Vector2i(2, 2),
	GRINDSTONE: Vector2i(2, 1),
	FINE_ENGRAVING: Vector2i(3, 3),
	OVERCOUNT_ENGRAVING: Vector2i(3, 3),
	FILE_DOWN: Vector2i(1, 1),
	DOUBLE_NOTCH: Vector2i(1, 2),
	AVERAGING: Vector2i(2, 2),
	CONNECT_UP: Vector2i(2, 2),
	MIRROR: Vector2i(2, 2),
	IMPRINT: Vector2i(3, 2),
	STRAIGHTEN: Vector2i(2, 3),
	BLUEPRINT: Vector2i(3, 3),
	# Material-Coupons (Coupon-id = Material-id, siehe DieMaterial).
	DieMaterial.GOLD: Vector2i(1, 1),
	DieMaterial.AMBER: Vector2i(2, 1),
	DieMaterial.GLASS: Vector2i(1, 2),
	DieMaterial.BONE: Vector2i(2, 2),
	DieMaterial.RUBY: Vector2i(2, 2),
	DieMaterial.MERCURY: Vector2i(3, 2),
	# Kanten-Coupons (ganzer Würfel, siehe KIND_EDGE) - stärker als die
	# Seiten-Variante, darum durchweg größere Flächen.
	EDGE_PREFIX + DieMaterial.GOLD: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.AMBER: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.GLASS: Vector2i(2, 2),
	EDGE_PREFIX + DieMaterial.BONE: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.RUBY: Vector2i(3, 2),
	EDGE_PREFIX + DieMaterial.MERCURY: Vector2i(3, 3),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = KIND_ETCHING
@export var rarity: Rarity = Rarity.COMMON
@export var width: int = 1  # Fläche in Rasterzellen (siehe FOOTPRINT)
@export var height: int = 1
@export var texture_path: String = ""  # Motiv-Textur (Konvention: TEXTURE_DIR + id + ".jpg")

static func _make(coupon_id: String, name: String, desc: String, rarity: Rarity, kind := KIND_ETCHING) -> Coupon:
	var coupon := Coupon.new()
	coupon.id = coupon_id
	coupon.display_name = name
	coupon.description = desc
	coupon.rarity = rarity
	coupon.kind = kind
	var size: Vector2i = FOOTPRINT.get(coupon_id, Vector2i.ONE)
	coupon.width = size.x
	coupon.height = size.y
	coupon.texture_path = TEXTURE_DIR + coupon_id + ".jpg"
	return coupon

# --- Ätzungen (etchings): verändern die Seiten EINES Würfels (siehe
# EtchingEffects; keine Ätzung berührt zwei Würfel). Face-Parameter der
# eigentlichen Wirkung wählt die Anwendungs-UI; hier zählen nur Metadaten. ---

## Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.
static func chisel() -> Coupon:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.COMMON)

## Transplantat (Fläche 2×2): hebt eine Seite auf den höchsten Wert des Würfels.
static func transplant() -> Coupon:
	return _make(TRANSPLANT, "Transplantat", "Hebe eine Seite auf den aktuell höchsten Wert des Würfels.", Rarity.COMMON)

## −1 auf eine Seite, +1 auf eine andere Seite desselben Würfels (Summe bleibt).
static func grindstone() -> Coupon:
	return _make(GRINDSTONE, "Schleifstein", "−1 auf eine Seite, +1 auf eine andere Seite desselben Würfels.", Rarity.COMMON)

## Setze eine Seite auf einen frei gewählten Wert 1–12.
static func fine_engraving() -> Coupon:
	return _make(FINE_ENGRAVING, "Feingravur", "Setze eine Seite auf einen frei gewählten Wert 1–12.", Rarity.UNCOMMON)

## +1 auf eine Seite, darf über 6 hinausgehen (siehe Überzahlen).
static func overcount_engraving() -> Coupon:
	return _make(OVERCOUNT_ENGRAVING, "Überzahl-Gravur", "+1 auf eine Seite, darf über 6 hinausgehen.", Rarity.RARE)

## Feile (Fläche 1×1): −1 auf eine Seite (min. 1) - der billigste Angleicher.
static func file_down() -> Coupon:
	return _make(FILE_DOWN, "Feile", "−1 auf eine Seite (min. 1).", Rarity.COMMON)

## Doppelkerbe (Fläche 1×2): +1 auf zwei verschiedene Seiten desselben Würfels.
static func double_notch() -> Coupon:
	return _make(DOUBLE_NOTCH, "Doppelkerbe", "+1 auf zwei verschiedene Seiten desselben Würfels (darf über 6 hinaus).", Rarity.COMMON)

## Mittelung (Fläche 2×2): zwei Seiten eines Würfels werden ihr aufgerundeter Mittelwert.
static func averaging() -> Coupon:
	return _make(AVERAGING, "Mittelung", "Zwei Seiten eines Würfels werden auf ihren aufgerundeten Mittelwert gesetzt.", Rarity.UNCOMMON)

## Anschluss (Fläche 2×2): setzt eine Seite auf (Wert einer anderen Seite +1) desselben Würfels.
static func connect_up() -> Coupon:
	return _make(CONNECT_UP, "Anschluss", "Setze eine Seite auf den Wert einer anderen Seite desselben Würfels +1 (darf über 6 hinaus).", Rarity.UNCOMMON)

## Spiegelung (Fläche 2×2): invertiert alle Seiten eines Würfels.
static func mirror() -> Coupon:
	return _make(MIRROR, "Spiegelung", "Invertiere alle Seiten eines Würfels ((Min+Max) − Wert).", Rarity.UNCOMMON)

## Abdruck (Fläche 2×3): prägt eine Seite auf die beiden niedrigsten anderen Seiten desselben Würfels.
static func imprint() -> Coupon:
	return _make(IMPRINT, "Abdruck", "Präge den Wert einer Seite auf die beiden niedrigsten anderen Seiten desselben Würfels.", Rarity.UNCOMMON)

## Begradigung (Fläche 2×3): +1 auf alle ungeraden Seiten eines Würfels.
static func straighten() -> Coupon:
	return _make(STRAIGHTEN, "Begradigung", "+1 auf alle ungeraden Seiten eines Würfels (darf über 6 hinaus).", Rarity.UNCOMMON)

## Blaupause (Fläche 3×3): setzt alle Seiten des Würfels auf den Wert einer gewählten Seite.
static func blueprint() -> Coupon:
	return _make(BLUEPRINT, "Blaupause", "Setze alle Seiten des Würfels auf den Wert einer gewählten Seite.", Rarity.RARE)

# --- Materialien (materials): belegen genau eine Würfelseite mit einer
# Veredelung (siehe DieMaterial/MaterialEffects). Die Coupon-id ist die
# Material-id; Name/Beschreibung kommen direkt vom Material - eine Quelle. ---

## Material-Coupon zu einem DieMaterial (siehe DieMaterial.all).
static func material_coupon(material: DieMaterial, rarity: Rarity) -> Coupon:
	return _make(material.id, material.display_name, material.description, rarity, KIND_MATERIAL)

## Kanten-Coupon zu einem DieMaterial: veredelt den GANZEN Würfel (siehe
## DieDefinition.edge_material) statt einer Seite - Wirkung siehe
## DieMaterial.edge_description / MaterialEffects.
static func edge_coupon(material: DieMaterial, rarity: Rarity) -> Coupon:
	return _make(EDGE_PREFIX + material.id, "%s-Kanten" % material.display_name, material.edge_description, rarity, KIND_EDGE)

## Seltenheit je Material-Coupon: Gold/Bernstein häufig (kleine, stetige
## Effekte), Glas/Knochen/Rubin ungewöhnlich, Quecksilber (Doppel-Zählung) selten.
const MATERIAL_RARITY := {
	DieMaterial.GOLD: Rarity.COMMON,
	DieMaterial.AMBER: Rarity.COMMON,
	DieMaterial.GLASS: Rarity.UNCOMMON,
	DieMaterial.BONE: Rarity.UNCOMMON,
	DieMaterial.RUBY: Rarity.UNCOMMON,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Seltenheit je Kanten-Coupon: eine Stufe über der Seiten-Variante (wirken
## bei jedem Wurf-Ergebnis des Würfels, nicht nur bei einer von 6 Seiten).
const EDGE_RARITY := {
	DieMaterial.GOLD: Rarity.UNCOMMON,
	DieMaterial.AMBER: Rarity.UNCOMMON,
	DieMaterial.GLASS: Rarity.RARE,
	DieMaterial.BONE: Rarity.RARE,
	DieMaterial.RUBY: Rarity.RARE,
	DieMaterial.MERCURY: Rarity.RARE,
}

## Alle existierenden Coupon-Archetypen (kanonische Registrierung) - Grundlage
## für die Bogen-Auswürfelung. Ein neuer Coupon wird hier eingehängt; die
## Material- und Kanten-Coupons kommen automatisch aus DieMaterial.all().
static func all() -> Array[Coupon]:
	var result: Array[Coupon] = [
		chisel(), transplant(), grindstone(), fine_engraving(), overcount_engraving(),
		file_down(), double_notch(), averaging(), connect_up(), mirror(), imprint(), straighten(), blueprint(),
	]
	for material in DieMaterial.all():
		result.append(material_coupon(material, MATERIAL_RARITY.get(material.id, Rarity.UNCOMMON)))
	for material in DieMaterial.all():
		result.append(edge_coupon(material, EDGE_RARITY.get(material.id, Rarity.RARE)))
	return result

## True, wenn coupon_id einen Kanten-Coupon bezeichnet (EDGE_PREFIX + gültige
## Material-id) - für die Anwendungs-UI (siehe DieInspectorView).
static func is_edge_id(coupon_id: String) -> bool:
	return coupon_id.begins_with(EDGE_PREFIX) and DieMaterial.is_valid_id(coupon_id.trim_prefix(EDGE_PREFIX))

## Die DieMaterial-id hinter diesem Coupon: direkt (Seiten-Material), ohne
## EDGE_PREFIX (Kanten) - oder "" bei Ätzungen. Für Material-Tints in der
## Anzeige (siehe CouponSheetView/DieInspectorView).
func material_id() -> String:
	match kind:
		KIND_MATERIAL:
			return id
		KIND_EDGE:
			return id.trim_prefix(EDGE_PREFIX)
	return ""

## Anzeigename der Seltenheit (deutsch).
static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON:
			return "häufig"
		Rarity.UNCOMMON:
			return "ungewöhnlich"
		Rarity.RARE:
			return "selten"
	return "?"

## Ziehgewicht je Seltenheit (relativ) - je seltener, desto seltener im Pack.
static func _rarity_weight(value: Rarity) -> int:
	match value:
		Rarity.COMMON:
			return 8
		Rarity.UNCOMMON:
			return 3
		Rarity.RARE:
			return 1
	return 1

