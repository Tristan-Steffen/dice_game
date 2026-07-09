class_name Coupon
extends Resource
## Ein verbrauchbarer "Coupon" - Karten, die man in Coupon-Packs (je 3 Karten)
## im Shop kauft (siehe ShopController) und unbegrenzt hortet. Aktuell sind alle
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

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = KIND_ETCHING
@export var rarity: Rarity = Rarity.COMMON

static func _make(coupon_id: String, name: String, desc: String, rarity: Rarity, kind := KIND_ETCHING) -> Coupon:
	var coupon := Coupon.new()
	coupon.id = coupon_id
	coupon.display_name = name
	coupon.description = desc
	coupon.rarity = rarity
	coupon.kind = kind
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

## Alle existierenden Coupon-Archetypen (kanonische Registrierung) - Grundlage
## für die Pack-Auswürfelung. Ein neuer Coupon wird hier eingehängt.
static func all() -> Array[Coupon]:
	return [chisel(), transplant(), grindstone(), fine_engraving(), overcount_engraving()]

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

## Eine zufällige Ätzung, gewichtet nach Seltenheit (siehe _rarity_weight).
## Jeder Aufruf liefert eine eigene, unabhängige Instanz (Coupons sind
## verbrauchbar).
static func random_etching() -> Coupon:
	var pool := all()
	var total := 0
	for coupon in pool:
		total += _rarity_weight(coupon.rarity)
	var roll := randi() % total
	for coupon in pool:
		roll -= _rarity_weight(coupon.rarity)
		if roll < 0:
			return coupon
	return pool[0]  # unerreichbar, nur zur Absicherung

## Ein Coupon-Pack: count zufällige Ätzungen (mit Wiederholung möglich, siehe
## Balatro-Packs - man erhält ALLE Karten), jede eine eigene Instanz.
static func random_etching_pack(count: int) -> Array[Coupon]:
	var pack: Array[Coupon] = []
	for i in count:
		pack.append(random_etching())
	return pack
