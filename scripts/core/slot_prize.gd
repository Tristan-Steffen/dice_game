class_name SlotPrize
extends RefCounted
## Ergebnis eines Fumble-Automaten: ein Gewinn (Pakete, Energie oder Würfel) oder
## das Namensgeber-Symbol „Fumble" (die Niete, löscht den Topf). Der Inhalt wird
## beim Drehen aufgelöst (Anzeige im Zwischenspeicher); GameRun bucht ihn beim
## Auszahlen - mit Multiplikator je Trefferzahl. Reine Daten, keine Nodes.
##
## Die drei Gravur-Sorten sind EIGENE Symbole (Zahlen/Material/Würfel) - dieselbe
## Dreiteilung wie Pakete im Laden und Schubladen an der Werkbank. Geld verdient
## man an den Runden, nicht am Automaten: ausgezahlt wird Ware oder Energie.
enum Kind { FUMBLE, ENGRAVING, MATERIAL, DICE_ENGRAVING, CHARGE, DIE, WILD }

## Paketsorte hinter einem Gravur-Symbol ("" = kein Gravur-Symbol).
static func pack_type_of(kind_value: int) -> String:
	match kind_value:
		Kind.ENGRAVING: return Pack.TYPE_NUMBER
		Kind.MATERIAL: return Pack.TYPE_MATERIAL
		Kind.DICE_ENGRAVING: return Pack.TYPE_DICE_MOD
	return ""

## Anzeigename der Paketsorte eines Symbols; count steuert den Plural.
static func pack_name(kind_value: int, count: int = 1) -> String:
	var type_name := String(Pack.TYPE_NAMES.get(pack_type_of(kind_value), "Paket"))
	return type_name if count == 1 else type_name + "e"

## Derselbe Name MIT Paketgröße ("2 Große Zahlen-Pakete"). Der Automat ist neben
## dem Laden die zweite Größenquelle, darum muss die Größe überall dranstehen, wo
## er seine Beute nennt - sie ist der ganze Unterschied zwischen einer 4er- und
## einer 6er-Reihe.
static func pack_name_tiered(kind_value: int, count: int = 1,
		pack_tier: int = Pack.TIER_NORMAL) -> String:
	var base := pack_name(kind_value, count)
	var adjective := Pack.tier_adjective(pack_tier, count)
	return base if adjective == "" else "%s %s" % [adjective, base]

var kind: int = Kind.FUMBLE
var packs: Array[Pack] = []      # Basis-Ausschüttung (vor Multiplikator)
var charge: int = 0              # Energie einer ⚡-Reihe
var die: DieDefinition = null
var label: String = "Fumble"    # Kurztext für den Zwischenspeicher

## Löst eine Gewinn-Vorlage (ein spec aus SlotMachine._run_specs) in einen konkreten
## Preis auf - Inhalt wird sofort gewürfelt, damit ihn der Zwischenspeicher zeigt.
static func from_spec(spec: Dictionary, hub_level: int = 1) -> SlotPrize:
	var p := SlotPrize.new()
	match String(spec.get("kind", "pack")):
		"pack":
			p.kind = int(spec.get("symbol", Kind.ENGRAVING))
			var count := maxi(1, int(spec.get("count", 1)))
			var pack_tier := int(spec.get("tier", Pack.TIER_NORMAL))
			var pack_type := pack_type_of(p.kind)
			for i in count:
				# Pack.tiered ist der eine Schreibweg: Aufschrift und Preis kommen mit.
				p.packs.append(Pack.tiered(Pack.by_type(pack_type), pack_tier))
			p.label = "%d %s" % [count, pack_name_tiered(p.kind, count, pack_tier)]
		"charge":
			p.kind = Kind.CHARGE
			p.charge = maxi(1, int(spec.get("amount", 1)))
			p.label = "%d⚡" % p.charge
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
		Kind.CHARGE: return "⚡"
		Kind.DIE: return "⬢"
		Kind.WILD: return "★"
	return "✖"   # Fumble

static func _roll_die(hub_level: int = 1) -> DieDefinition:
	var offers := DiceOffer.roll_offers(1, [], [], hub_level)
	if offers.is_empty() or offers[0].dice.is_empty():
		return DieDefinition.standard()
	return offers[0].dice[0]
