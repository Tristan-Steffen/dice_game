class_name RuneEffects
## Reine Wirkung der Runen (siehe Rune), über die id aufgelöst - nie ein stiller
## Zweig in scene_root. Eine Rune gehört EINER Seite und wirkt nur, wenn diese
## Seite oben liegt; Leiterbahn-Glieder feuern ihn NICHT (siehe DiceScoring).
##
## Zwei Klassen: WERTUNGS-Runen feuern, wenn die Seite gewertet wird
## (Nachglühen, Funkenflug); ÖKONOMIE-/SCHUTZ-Runen hängen an anderen Ereignissen
## (Streulicht am Zugende, Einbrand als Dauerzustand der Seite).

## Streulicht zahlt je ungewertetem Würfel am Zugende.
const STRAY_LIGHT_MONEY := 1

## Funkenflug speist EINEN Funken je Zug - nicht je Auslösung, sonst würde ein
## Argon-Würfel die Bank doppelt füllen.
const SPARK_FLIGHT_CHARGE := 1

## ZUSÄTZLICHE Auslösungen aus die Runen der oben liegenden Seite. Additiv wie
## Retrigger-Charms, Echo und Sauerstoff - die Essenz bleibt die einzige
## multiplikative Quelle.
static func extra_activations(rune_ids: Array[String]) -> int:
	var extra := 0
	for rune_id in rune_ids:
		if rune_id == Rune.AFTERGLOW:
			extra += 1
	return extra

## Einbrand: der Wert dieser Seite ist eingebrannt - er schrumpft nicht (Glas,
## Radon-Zerfall) und ihr Material lässt sich nicht übermalen.
static func protects_face_value(rune_ids: Array[String]) -> bool:
	return rune_ids.has(Rune.BURN_IN)

## Energie, die die gewertete Seite in DIESEM Zug abgibt (Funkenflug) - je Zug
## einmal, unabhängig von der Zahl der Auslösungen.
static func charge_for_take(rune_ids: Array[String]) -> int:
	return SPARK_FLIGHT_CHARGE if rune_ids.has(Rune.SPARK_FLIGHT) else 0

## Geld einer LIEGENDEN, aber ungewerteten Seite am Zugende (Streulicht) - das
## bewusste Gegen-Ereignis zum Gold-Material.
static func stray_money(rune_ids: Array[String]) -> int:
	return STRAY_LIGHT_MONEY if rune_ids.has(Rune.STRAY_LIGHT) else 0

## Runen eines Slots aus dem ctx-Dictionary ([] = keine).
static func runes_at(runes: Dictionary, slot: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(runes.get(slot, []))
	return out

## Tönung, in der die Runen dieses Würfels leuchten: das Vakuum zieht das
## Kernlicht nach innen, seine Runen sind SCHWARZ - egal welcher Rune.
static func glyph_color(rune_id: String, essence_id: String) -> Color:
	if essence_id == Essence.VACUUM:
		return Color(0.02, 0.02, 0.04)
	return Rune.tint_for(rune_id)
