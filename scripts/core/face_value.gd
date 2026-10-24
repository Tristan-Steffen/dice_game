class_name FaceValue
extends RefCounted
## Die EINE Schreibweise einer Augenzahl. Ab BIG_FROM liest sie zweiteilig: groß die
## KOMBINATIONSZIFFER (Wert % 10, DiceScoring._digit), klein darüber die GRÖSSE
## ("1.00k", "12.5k", "2.30M") - abgerundet, damit sie nie mehr verspricht.

const BIG_FROM := 1000
const SUFFIXES := ["", "k", "M", "B", "T"]

static func is_big(value: int) -> bool:
	return absi(value) >= BIG_FROM

## Die Kombinationsziffer - für Paar, Straße und Co. zählt nur sie.
static func digit(value: int) -> int:
	return absi(value) % 10

## Die Größe mit drei gültigen Stellen ("" unter BIG_FROM).
static func magnitude(value: int) -> String:
	if not is_big(value):
		return ""
	# Ganzzahlig in Hundertsteln der Einheit - Fließkomma rundete 2,30M auf 2,29M.
	var whole := absi(value)
	var unit := 1
	var step := 0
	while whole / unit >= 1000 and step < SUFFIXES.size() - 1:
		unit *= 1000
		step += 1
	var hundredths := whole / (unit / 100)
	var shown := ""
	if hundredths >= 10000:
		shown = str(hundredths / 100)
	elif hundredths >= 1000:
		shown = "%d.%d" % [hundredths / 100, (hundredths / 10) % 10]
	else:
		shown = "%d.%02d" % [hundredths / 100, hundredths % 100]
	return ("-" if value < 0 else "") + shown + String(SUFFIXES[step])

## Die Hauptzeile: die volle Zahl, ab BIG_FROM nur noch die Kombinationsziffer.
static func main_text(value: int) -> String:
	return str(digit(value)) if is_big(value) else str(value)

## Einzeilig für Text (Info-Schirm, Vorschau): "1.00k·4".
static func inline(value: int) -> String:
	return "%s·%d" % [magnitude(value), digit(value)] if is_big(value) else str(value)
