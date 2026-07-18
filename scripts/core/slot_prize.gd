class_name SlotPrize
extends RefCounted
## Ergebnis eines Fumble-Automaten: ein Gewinn (Geld, Sigille, Charm oder Würfel)
## oder das Namensgeber-Symbol „Fumble" (die Niete, löscht den Topf). Der Inhalt
## wird beim Drehen aufgelöst (Anzeige im Zwischenspeicher); GameRun bucht ihn beim
## Auszahlen - mit Multiplikator je Trefferzahl. Reine Daten, keine Nodes.

enum Kind { FUMBLE, MONEY, SIGIL, CHARM, DIE }

var kind: int = Kind.FUMBLE
var money: int = 0
var sigils: Array[Sigil] = []   # Basis-Ausschüttung (vor Multiplikator)
var charm: Charm = null
var die: DieDefinition = null
var label: String = "Fumble"    # Kurztext für den Zwischenspeicher

static func fumble() -> SlotPrize:
	var p := SlotPrize.new()
	p.kind = Kind.FUMBLE
	p.label = "Fumble"
	return p

## Löst eine Gewinn-Vorlage (SlotMachine.PRIZE_TABLES-Eintrag) in einen konkreten
## Preis auf - Inhalt wird sofort gewürfelt, damit ihn der Zwischenspeicher zeigt.
static func from_spec(spec: Dictionary) -> SlotPrize:
	var p := SlotPrize.new()
	match String(spec.get("kind", "money")):
		"money":
			p.kind = Kind.MONEY
			p.money = int(spec.get("amount", 0))
			p.label = "$%d" % p.money
		"sigil":
			p.kind = Kind.SIGIL
			var count := int(spec.get("count", 1))
			p.sigils = Sigil.roll_draft(count, int(spec.get("floor", Sigil.Rarity.COMMON)))
			var n := maxi(1, p.sigils.size())
			p.label = "%d Sigill%s" % [n, "" if n == 1 else "e"]
		"charm":
			p.kind = Kind.CHARM
			p.charm = _roll_charm(String(spec.get("floor", Charm.RARITY_COMMON)))
			p.label = p.charm.display_name if p.charm != null else "Charm"
		"die":
			p.kind = Kind.DIE
			p.die = _roll_die()
			p.label = p.die.display_name if p.die != null else "Würfel"
	return p

## Neon-Glyphe der Walze (siehe SlotBankView).
func symbol() -> String:
	return symbol_for(kind)

## Symbol-Glyphe eines Kind (auch für bloße Wand-Symbole ohne aufgelösten Preis).
static func symbol_for(kind_value: int) -> String:
	match kind_value:
		Kind.MONEY: return "$"
		Kind.SIGIL: return "◈"
		Kind.CHARM: return "✦"
		Kind.DIE: return "⬢"
	return "✖"   # Fumble

## Zufälliger Charm mindestens der Rarität floor_name, gewichtet (fällt auf den
## vollen Pool zurück, falls die Untergrenze nichts übrig lässt).
static func _roll_charm(floor_name: String) -> Charm:
	var order := [Charm.RARITY_COMMON, Charm.RARITY_UNCOMMON, Charm.RARITY_RARE, Charm.RARITY_LEGENDARY]
	var floor_idx := maxi(0, order.find(floor_name))
	var pool: Array[Charm] = []
	for charm in Charm.all():
		if order.find(charm.rarity) >= floor_idx:
			pool.append(charm)
	if pool.is_empty():
		pool = Charm.all()
	return Charm.pick_weighted(pool)

static func _roll_die() -> DieDefinition:
	var offers := DiceOffer.roll_offers(1)
	if offers.is_empty() or offers[0].dice.is_empty():
		return DieDefinition.standard()
	return offers[0].dice[0]
