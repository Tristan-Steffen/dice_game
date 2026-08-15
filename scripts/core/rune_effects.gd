class_name RuneEffects
## Reine Wirkung der Runen (siehe Rune), über die id aufgelöst - nie ein stiller
## Zweig in scene_root. Eine Rune gehört EINER Seite und wirkt nur, wenn diese
## Seite oben liegt; Pointer-Glieder feuern ihn NICHT (siehe DiceScoring).
##
## Zwei Klassen: WERTUNGS-Runen feuern, wenn die Seite gewertet wird
## (Nachglühen, Funkenflug, Kehrseite); ÖKONOMIE-/SCHUTZ-Runen hängen an anderen
## Ereignissen (Streulicht am Zugende, Abguss beim Werten in den Vorrat, Einbrand
## als Dauerzustand der Seite).
##
## Die Kehrseite steht bewusst NICHT hier: sie ist ein deterministisches Glied
## und wohnt darum in EssenceEffects.link_faces - sie feuert EINMAL nach allen
## Würfel-Triggern, während das Röntgenlicht je Antritt belichtet.

## Streulicht zahlt je ungewertetem Würfel am Zugende.
const STRAY_LIGHT_MONEY := 1

## Funkenflug speist EINEN Funken je Zug - nicht je Auslösung, sonst würde ein
## Argon-Würfel die Bank doppelt füllen.
const SPARK_FLIGHT_CHARGE := 1

## Stichel: JEDE Rune wirkt doppelt - Nachglühen, Funkenflug, Streulicht und der
## Abguss (GameRun.apply_rune_cast); die Kehrseite zündet über
## EssenceEffects.det_link_fire_count zweimal. Nur der Einbrand kennt keine
## Verdopplung, er ist ein Dauerzustand und kein Betrag.
static func burin_factor(charm_ids: Array[String]) -> int:
	return 2 if charm_ids.has(Charm.BURIN) else 1

## ZUSÄTZLICHE Auslösungen aus die Runen der oben liegenden Seite. Additiv wie
## Retrigger-Charms, Echo und Sauerstoff - die Essenz bleibt die einzige
## multiplikative Quelle.
static func extra_activations(rune_ids: Array[String], charm_ids: Array[String] = []) -> int:
	var extra := 0
	for rune_id in rune_ids:
		if rune_id == Rune.AFTERGLOW:
			extra += burin_factor(charm_ids)
	return extra

## Einbrand: der Wert dieser Seite ist eingebrannt - er schrumpft nicht (Glas,
## Radon-Zerfall) und ihr Material lässt sich nicht übermalen.
static func protects_face_value(rune_ids: Array[String]) -> bool:
	return rune_ids.has(Rune.BURN_IN)

## Energie, die die gewertete Seite in DIESEM Zug abgibt (Funkenflug) - je Zug
## einmal, unabhängig von der Zahl der Auslösungen.
static func charge_for_take(rune_ids: Array[String], charm_ids: Array[String] = []) -> int:
	if not rune_ids.has(Rune.SPARK_FLIGHT):
		return 0
	return SPARK_FLIGHT_CHARGE * burin_factor(charm_ids)

## Abguss: nimmt die gewertete Seite eine Kopie ihrer Material-Gravur mit in den
## Vorrat? Nur das Prädikat - gebucht wird in GameRun (die fünfte Wirkungsform:
## sie greift in den Vorrat, nicht in die Wertung).
static func casts_material(rune_ids: Array[String]) -> bool:
	return rune_ids.has(Rune.CAST)

## Geld einer LIEGENDEN, aber ungewerteten Seite am Zugende (Streulicht) - das
## bewusste Gegen-Ereignis zum Gold-Material.
static func stray_money(rune_ids: Array[String], charm_ids: Array[String] = []) -> int:
	if not rune_ids.has(Rune.STRAY_LIGHT):
		return 0
	return STRAY_LIGHT_MONEY * burin_factor(charm_ids)

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
