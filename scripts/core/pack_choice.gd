class_name PackChoice
extends RefCounted
## Ein GEÖFFNETES Paket: seine Optionen und die Zahl der Wahlen stehen ab dem Kauf
## fest (gebucht in GameRun.pending_pack_choices); die Grube zeigt nur. Karten- und
## Würfel-Pakete teilen diesen einen Datensatz.

const KIND_CARDS := "cards"
const KIND_DICE := "dice"

var kind: String = KIND_CARDS
## Das Paket selbst (CardPack oder DicePack) - Name, Sorte, Größe.
var pack: Resource = null
## Je Option eine Karte (Pack) oder ein Würfel (DieDefinition).
var options: Array = []
var picks: int = 1
## Nur Würfel-Pakete: je Option ihre Güte (parallel zu options) und die Grundzahlen,
## von denen die Ketten ausgingen (Anzeige: Augen, Leiter).
var qualities: Array[int] = []
var base_count: int = 0
var base_picks: int = 0
## Freie Hand galt beim Öffnen (Würfel: Wahlen = Zahl - 1, auch nach Neu mischen).
var free_hand: bool = false
## Hauptgewinn oder Freie Hand: alle Optionen nehmen (nur Karten-Pakete).
var take_all: bool = false
var jackpot: bool = false
## Neu mischen ist je Paket einmal erlaubt.
var rerolled: bool = false
## Woher es kam (Laden-Kauf oder Wett-Gewinn) - nur Anzeige.
var from_bet: bool = false

func is_dice() -> bool:
	return kind == KIND_DICE

func option_count() -> int:
	return options.size()

var display_name: String:
	get:
		if pack is CardPack:
			return (pack as CardPack).display_name
		if pack is DicePack:
			return (pack as DicePack).display_name
		return "Paket"

var size: int:
	get:
		if pack is CardPack:
			return (pack as CardPack).size
		if pack is DicePack:
			return (pack as DicePack).size
		return CardPack.SIZE_NORMAL

## Die Güte des Pakets (Karten-Pakete: Standard).
var quality: int:
	get:
		return (pack as DicePack).quality if pack is DicePack else DicePack.QUALITY_STANDARD

## Die Güte der Option i (Karten und Fehlendes: Standard).
func quality_of(index: int) -> int:
	return qualities[index] if index >= 0 and index < qualities.size() \
		else DicePack.QUALITY_STANDARD

## Ob diese Auswahl gültig ist: verschiedene, vorhandene Optionen, höchstens picks.
func valid_selection(indices: Array) -> bool:
	if indices.size() > picks:
		return false
	var seen := {}
	for index in indices:
		var i := int(index)
		if i < 0 or i >= options.size() or seen.has(i):
			return false
		seen[i] = true
	return true
