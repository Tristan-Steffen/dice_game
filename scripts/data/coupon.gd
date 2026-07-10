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

# kind eines Coupons (aktuell nur Ätzungen; künftig MATERIAL, SIGIL).
const KIND_ETCHING := "etching"

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
const TEXTURE_DIR := "res://assets/textures/egnravings/"

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
}

# Texturdatei je Coupon (im TEXTURE_DIR).
const TEXTURE_FILE := {
	CHISEL: "Meißel3x2.jpg",
	TRANSPLANT: "Transplantat2x2.jpg",
	GRINDSTONE: "Schleifstein-horizontal2x1.jpg",
	FINE_ENGRAVING: "Feingravur3x3.jpg",
	OVERCOUNT_ENGRAVING: "Überzahl-Gravur3x3.jpg",
	FILE_DOWN: "Feiel1x1.jpg",
	DOUBLE_NOTCH: "doppelkerbe-vertikal1x2.jpg",
	AVERAGING: "Mittelung2x2.jpg",
	CONNECT_UP: "Anschluss2x2.jpg",
	MIRROR: "Spiegelung2x2.jpg",
	IMPRINT: "Abdruck3x2.jpg",
	STRAIGHTEN: "Begradigung2x3.jpg",
	BLUEPRINT: "Blaupause3x3.jpg",
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = KIND_ETCHING
@export var rarity: Rarity = Rarity.COMMON
@export var width: int = 1  # Fläche in Rasterzellen (siehe FOOTPRINT)
@export var height: int = 1
@export var texture_path: String = ""  # Motiv-Textur (siehe TEXTURE_FILE)

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
	if TEXTURE_FILE.has(coupon_id):
		coupon.texture_path = TEXTURE_DIR + TEXTURE_FILE[coupon_id]
	return coupon

# --- Ätzungen (etchings): verändern die Seiten eines/zweier Würfel (siehe
# EtchingEffects). Face-Parameter der eigentlichen Wirkung folgen erst mit der
# Anwendungs-UI; hier zählen nur Metadaten. ---

## Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.
static func chisel() -> Coupon:
	return _make(CHISEL, "Meißel", "Kopiere eine Seite eines Würfels auf eine andere Seite desselben Würfels.", Rarity.COMMON)

## Tausche zwei Seiten zwischen zwei verschiedenen Würfeln.
static func transplant() -> Coupon:
	return _make(TRANSPLANT, "Transplantat", "Tausche zwei Seiten zwischen zwei verschiedenen Würfeln.", Rarity.COMMON)

## −1 auf eine Seite, +1 auf eine andere Seite desselben Würfels (Summe bleibt).
static func grindstone() -> Coupon:
	return _make(GRINDSTONE, "Schleifstein", "−1 auf eine Seite, +1 auf eine andere Seite desselben Würfels.", Rarity.COMMON)

## Setze eine Seite auf einen frei gewählten Wert 1–6.
static func fine_engraving() -> Coupon:
	return _make(FINE_ENGRAVING, "Feingravur", "Setze eine Seite auf einen frei gewählten Wert 1–6.", Rarity.UNCOMMON)

## +1 auf eine Seite, darf über 6 hinausgehen (siehe Überzahlen).
static func overcount_engraving() -> Coupon:
	return _make(OVERCOUNT_ENGRAVING, "Überzahl-Gravur", "+1 auf eine Seite, darf über 6 hinausgehen.", Rarity.RARE)

## Feile (Fläche 1×1): −1 auf eine Seite (min. 1) - der billigste Angleicher.
static func file_down() -> Coupon:
	return _make(FILE_DOWN, "Feile", "−1 auf eine Seite (min. 1).", Rarity.COMMON)

## Doppelkerbe (Fläche 1×2): +1 auf zwei verschiedene Seiten desselben Würfels.
static func double_notch() -> Coupon:
	return _make(DOUBLE_NOTCH, "Doppelkerbe", "+1 auf zwei verschiedene Seiten desselben Würfels (max. 6).", Rarity.COMMON)

## Mittelung (Fläche 2×2): zwei Seiten eines Würfels werden ihr aufgerundeter Mittelwert.
static func averaging() -> Coupon:
	return _make(AVERAGING, "Mittelung", "Zwei Seiten eines Würfels werden auf ihren aufgerundeten Mittelwert gesetzt.", Rarity.UNCOMMON)

## Anschluss (Fläche 2×2): setzt eine Seite eines ANDEREN Würfels auf (gewählte Seite +1).
static func connect_up() -> Coupon:
	return _make(CONNECT_UP, "Anschluss", "Setze eine Seite eines anderen Würfels auf den Wert der gewählten Seite +1 (max. 6).", Rarity.UNCOMMON)

## Spiegelung (Fläche 2×2): invertiert alle Seiten eines Würfels.
static func mirror() -> Coupon:
	return _make(MIRROR, "Spiegelung", "Invertiere alle Seiten eines Würfels ((Min+Max) − Wert).", Rarity.UNCOMMON)

## Abdruck (Fläche 2×3): kopiert eine Seite auf eine Seite eines ANDEREN Würfels.
static func imprint() -> Coupon:
	return _make(IMPRINT, "Abdruck", "Kopiere eine Seite auf eine Seite eines anderen Würfels.", Rarity.UNCOMMON)

## Begradigung (Fläche 2×3): +1 auf alle ungeraden Seiten eines Würfels.
static func straighten() -> Coupon:
	return _make(STRAIGHTEN, "Begradigung", "+1 auf alle ungeraden Seiten eines Würfels (max. 6).", Rarity.UNCOMMON)

## Blaupause (Fläche 3×3): kopiert den kompletten Seitensatz eines Würfels auf einen anderen.
static func blueprint() -> Coupon:
	return _make(BLUEPRINT, "Blaupause", "Kopiere den kompletten Seitensatz eines Würfels auf einen anderen.", Rarity.RARE)

## Alle existierenden Coupon-Archetypen (kanonische Registrierung) - Grundlage
## für die Pack-Auswürfelung. Ein neuer Coupon wird hier eingehängt.
static func all() -> Array[Coupon]:
	return [
		chisel(), transplant(), grindstone(), fine_engraving(), overcount_engraving(),
		file_down(), double_notch(), averaging(), connect_up(), mirror(), imprint(), straighten(), blueprint(),
	]

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

