class_name RiftEffects
## Reine Wirkung der Rifts (siehe Rift), über die id aufgelöst - nie ein stiller
## Zweig in scene_root. Ein Rift gehört EINER Seite und wirkt nur, wenn diese
## Seite oben liegt; Leiterbahn-Glieder feuern ihn NICHT (siehe DiceScoring).
##
## Zwei Klassen: WERTUNGS-Rifts feuern, wenn die Seite gewertet wird
## (Nachglühen, Funkenflug); ÖKONOMIE-/SCHUTZ-Rifts hängen an anderen Ereignissen
## (Streulicht am Zugende, Einbrand als Dauerzustand der Seite).

## Streulicht zahlt je ungewertetem Würfel am Zugende.
const STRAY_LIGHT_MONEY := 1

## Funkenflug speist EINEN Funken je Zug - nicht je Auslösung, sonst würde ein
## Argon-Würfel die Bank doppelt füllen.
const SPARK_FLIGHT_CHARGE := 1

## ZUSÄTZLICHE Auslösungen aus den Rifts der oben liegenden Seite. Additiv wie
## Retrigger-Charms, Echo und Sauerstoff - die Essenz bleibt die einzige
## multiplikative Quelle.
static func extra_activations(rift_ids: Array[String]) -> int:
	var extra := 0
	for rift_id in rift_ids:
		if rift_id == Rift.AFTERGLOW:
			extra += 1
	return extra

## Einbrand: der Wert dieser Seite ist eingebrannt - er schrumpft nicht (Glas,
## Radon-Zerfall) und ihr Material lässt sich nicht übermalen.
static func protects_face_value(rift_ids: Array[String]) -> bool:
	return rift_ids.has(Rift.BURN_IN)

## Energie, die die gewertete Seite in DIESEM Zug abgibt (Funkenflug) - je Zug
## einmal, unabhängig von der Zahl der Auslösungen.
static func charge_for_take(rift_ids: Array[String]) -> int:
	return SPARK_FLIGHT_CHARGE if rift_ids.has(Rift.SPARK_FLIGHT) else 0

## Geld einer LIEGENDEN, aber ungewerteten Seite am Zugende (Streulicht) - das
## bewusste Gegen-Ereignis zum Gold-Material.
static func stray_money(rift_ids: Array[String]) -> int:
	return STRAY_LIGHT_MONEY if rift_ids.has(Rift.STRAY_LIGHT) else 0

## Rifts eines Slots aus dem ctx-Dictionary ([] = keine).
static func rifts_at(rifts: Dictionary, slot: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(rifts.get(slot, []))
	return out

## Tönung, in der die Risse dieses Würfels brechen: das Vakuum zieht das
## Kernlicht nach innen, seine Risse sind SCHWARZ - egal welcher Rift.
static func crack_color(rift_id: String, essence_id: String) -> Color:
	if essence_id == Essence.VACUUM:
		return Color(0.02, 0.02, 0.04)
	return Rift.tint_for(rift_id)
