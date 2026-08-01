class_name SlotPrize
extends RefCounted
## Ergebnis eines Fumble-Automaten: ein Gewinn (Gravuren, Charm oder Würfel) oder
## das Namensgeber-Symbol „Fumble" (die Niete, löscht den Topf). Der Inhalt wird
## beim Drehen aufgelöst (Anzeige im Zwischenspeicher); GameRun bucht ihn beim
## Auszahlen - mit Multiplikator je Trefferzahl. Reine Daten, keine Nodes.
##
## Die drei Gravur-Sorten sind EIGENE Symbole (Zahlen/Material/Würfel) - dieselbe
## Dreiteilung wie Pakete im Laden und Schubladen an der Werkbank. Der Automat
## zahlt NUR in Ware; Geld verdient man an den Runden, nicht am Automaten.
enum Kind { FUMBLE, ENGRAVING, MATERIAL, DICE_ENGRAVING, CHARM, DIE }

## Gravur-Kategorie eines Symbol-Kinds ("" = kein Gravur-Symbol).
static func category_of(kind_value: int) -> String:
	match kind_value:
		Kind.ENGRAVING: return Engraving.CATEGORY_NUMBER
		Kind.MATERIAL: return Engraving.CATEGORY_MATERIAL
		Kind.DICE_ENGRAVING: return Engraving.CATEGORY_DICE
	return ""

var kind: int = Kind.FUMBLE
var engravings: Array[Engraving] = []   # Basis-Ausschüttung (vor Multiplikator)
var charm: Charm = null
var die: DieDefinition = null
var label: String = "Fumble"    # Kurztext für den Zwischenspeicher

## Löst eine Gewinn-Vorlage (SlotMachine.PRIZE_TABLES-Eintrag) in einen konkreten
## Preis auf - Inhalt wird sofort gewürfelt, damit ihn der Zwischenspeicher zeigt.
static func from_spec(spec: Dictionary, hub_level: int = 1) -> SlotPrize:
	var p := SlotPrize.new()
	match String(spec.get("kind", "engraving")):
		"engraving":
			p.kind = int(spec.get("symbol", Kind.ENGRAVING))
			var count := int(spec.get("count", 1))
			var floor_rarity := int(spec.get("floor", Engraving.Rarity.COMMON))
			var category := category_of(p.kind)
			if category == "":
				p.engravings = Engraving.roll_draft(count, floor_rarity)
			else:
				p.engravings = Engraving.roll_in_category(category, count, floor_rarity)
			var n := maxi(1, p.engravings.size())
			p.label = "%d %s" % [n, category_name(p.kind, n)]
		"charm":
			p.kind = Kind.CHARM
			p.charm = _roll_charm(String(spec.get("rarity", Charm.RARITY_COMMON)))
			p.label = p.charm.display_name if p.charm != null else "Charm"
		"die":
			p.kind = Kind.DIE
			p.die = _roll_die(hub_level)
			p.label = p.die.display_name if p.die != null else "Würfel"
	return p

## Symbol-Glyphe eines Kind (auch für bloße Wand-Symbole ohne aufgelösten Preis).
## Die Zeichen folgen der Bildsprache der Paket-Siegel: Auge für Zahlen, Stein für
## Material, Rahmen für Würfel-Gravuren (siehe PackIconRenderer).
static func symbol_for(kind_value: int) -> String:
	match kind_value:
		Kind.ENGRAVING: return "◉"
		Kind.MATERIAL: return "◆"
		Kind.DICE_ENGRAVING: return "▣"
		Kind.CHARM: return "✦"
		Kind.DIE: return "⬢"
	return "✖"   # Fumble

## Anzeigename eines Symbols; count steuert den Plural.
static func category_name(kind_value: int, count: int = 1) -> String:
	match kind_value:
		Kind.ENGRAVING: return "Gravur" if count == 1 else "Gravuren"
		Kind.MATERIAL: return "Material" if count == 1 else "Materialien"
		Kind.DICE_ENGRAVING: return "Würfel-Gravur" if count == 1 else "Würfel-Gravuren"
		Kind.CHARM: return "Charm" if count == 1 else "Charms"
		Kind.DIE: return "Würfel"
	return "Fumble"

## Zufälliger Charm GENAU der Rarität rarity_name, gewichtet. Fehlt diese Stufe,
## eine Stufe tiefer, bis der Pool nicht leer ist.
static func _roll_charm(rarity_name: String) -> Charm:
	var order := [Charm.RARITY_COMMON, Charm.RARITY_UNCOMMON, Charm.RARITY_RARE, Charm.RARITY_LEGENDARY]
	var idx := maxi(0, order.find(rarity_name))
	while idx >= 0:
		var pool: Array[Charm] = []
		for charm in Charm.all():
			if charm.rarity == order[idx]:
				pool.append(charm)
		if not pool.is_empty():
			return Charm.pick_weighted(pool)
		idx -= 1
	return Charm.pick_weighted(Charm.all())

static func _roll_die(hub_level: int = 1) -> DieDefinition:
	var offers := DiceOffer.roll_offers(1, [], [], hub_level)
	if offers.is_empty() or offers[0].dice.is_empty():
		return DieDefinition.standard()
	return offers[0].dice[0]
