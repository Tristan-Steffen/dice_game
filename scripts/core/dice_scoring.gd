class_name DiceScoring
## Reine Wertungslogik (Balatro-artig): Punkte = Basiswert × Multiplikator.
## Basiswert = feste Kategorie-Punkte + beteiligte Würfelaugen. Verwandlungs-
## Charms (CharmEffects.transform_values) ändern die Augen VOR der Erkennung -
## eine verwandelte 1 IST eine 6, auch für die Kategorie. Alle anderen Charms,
## Materialien und Menü-Stufen verändern nur die Wertung.

# Kategorie-Keys als Konstanten: ein Tippfehler wird Compilerfehler statt
# einer still nie zutreffenden Kategorie.
const ONE_KIND := "one_kind"
const TWO_KIND := "two_kind"
const TWO_PAIR := "two_pair"
const THREE_KIND := "three_kind"
const SMALL_STRAIGHT := "small_straight"
const FOUR_KIND := "four_kind"
const FULL_HOUSE := "full_house"
const THREE_PAIRS := "three_pairs"
const DOUBLE_THREE_KIND := "double_three_kind"
const FOUR_KIND_AND_PAIR := "four_kind_and_pair"
const LARGE_STRAIGHT := "large_straight"
const FIVE_KIND := "five_kind"
const SIX_KIND := "six_kind"

## Basiswerte und die Übertaktungs-Schritte je Stufe. Die Schritte sind AUTORIERT,
## nicht abgeleitet: würde jede Stufe die Basis erneut addieren, wüchse das feste
## Produkt quadratisch und der Sechserpasch zöge um das 180-fache der Höchsten
## Zahl davon. Höchste Zahl und Paar behalten ihren alten Schritt.
const CATEGORIES := [
	{"key": ONE_KIND, "label": "Höchste Zahl", "mult": 1, "points": 5, "mult_step": 1, "points_step": 5},
	{"key": TWO_KIND, "label": "Paar", "mult": 2, "points": 10, "mult_step": 2, "points_step": 10},
	{"key": TWO_PAIR, "label": "Zwei Paare", "mult": 3, "points": 15, "mult_step": 2, "points_step": 10},
	{"key": THREE_KIND, "label": "Dreierpasch", "mult": 3, "points": 18, "mult_step": 2, "points_step": 10},
	{"key": SMALL_STRAIGHT, "label": "Kleine Straße", "mult": 4, "points": 22, "mult_step": 2, "points_step": 12},
	{"key": FOUR_KIND, "label": "Viererpasch", "mult": 4, "points": 25, "mult_step": 3, "points_step": 12},
	{"key": FULL_HOUSE, "label": "Full House", "mult": 4, "points": 28, "mult_step": 3, "points_step": 14},
	{"key": THREE_PAIRS, "label": "Drei Zweierpäsche", "mult": 5, "points": 32, "mult_step": 3, "points_step": 16},
	{"key": DOUBLE_THREE_KIND, "label": "Doppelter Dreierpasch", "mult": 5, "points": 36, "mult_step": 3, "points_step": 18},
	{"key": FOUR_KIND_AND_PAIR, "label": "Viererpasch mit Paar", "mult": 6, "points": 40, "mult_step": 3, "points_step": 20},
	{"key": LARGE_STRAIGHT, "label": "Große Straße", "mult": 8, "points": 45, "mult_step": 4, "points_step": 22},
	{"key": FIVE_KIND, "label": "5 of a Kind", "mult": 10, "points": 50, "mult_step": 4, "points_step": 25},
	{"key": SIX_KIND, "label": "Sechserpasch", "mult": 15, "points": 60, "mult_step": 4, "points_step": 30},
]

# Prestigeträchtigste zuerst: best_hand() nimmt den ERSTEN Treffer dieser Liste,
# ohne Punktvergleich. So stehen spezifischere Häuser (3+3, 4+2) vor Full
# House/Zwei Paare, die sie sonst mit abdecken würden.
const HAND_PRIORITY := [
	SIX_KIND, FIVE_KIND, LARGE_STRAIGHT, FOUR_KIND_AND_PAIR, DOUBLE_THREE_KIND,
	THREE_PAIRS, FOUR_KIND, FULL_HOUSE, SMALL_STRAIGHT, THREE_KIND, TWO_PAIR, TWO_KIND, ONE_KIND,
]

## Drossel (ctx-Schlüssel): Array der gedrosselten Kategorien - sie werten 0,
## best_hand fällt auf die nächstbeste zutreffende zurück. Mehrzahl, weil Boss-
## Konditionen (Allrounder, Standardprotokoll) die Liste wachsen lassen.
const CTX_THROTTLED := "throttled"

## Ob eine Kategorie in diesem Wurf gedrosselt ist.
static func is_throttled(key: String, ctx: Dictionary) -> bool:
	var throttled: Array = ctx.get(CTX_THROTTLED, [])
	return throttled.has(key)

## Paritäts-Filter (ctx-Schlüssel): die Boss-Konditionen Schieflage/Gleichgewicht
## lassen nur ungerade bzw. gerade Augen an einer Kombination teilnehmen. Der
## Filter greift VOR der Erkennung - ausgeschlossene Würfel bilden keine Gruppe,
## keine Straße und keine "Höchste Zahl", ein Wurf ohne legale Würfel farkelt.
const CTX_PARITY := "parity"
const PARITY_ANY := 0
const PARITY_ODD := 1
const PARITY_EVEN := 2

## Slots, die unter dem Paritäts-Filter überhaupt werten dürfen. KEINE Essenz
## nimmt einen Würfel aus der Sperre - auch Krypton nicht, dessen "zählt immer
## mit" die Kombination weitet, nicht die Klausel aushebelt.
static func legal_indices(dice: Array[int], ctx: Dictionary) -> Array[int]:
	var legal: Array[int] = []
	var parity := int(ctx.get(CTX_PARITY, PARITY_ANY))
	for i in dice.size():
		if parity == PARITY_ANY or (absi(dice[i]) % 2 == 1) == (parity == PARITY_ODD):
			legal.append(i)
	return legal

## Die legalen Würfel als eigene Liste - qualifies/participating rechnen darauf
## und der Aufrufer bildet die Indizes über legal_indices zurück.
static func _legal_dice(dice: Array[int], legal: Array[int]) -> Array[int]:
	var sub: Array[int] = []
	for i in legal:
		sub.append(dice[i])
	return sub

## Deterministische Glieder (ctx-Schlüssel): Dictionary Slot -> Glieder-Liste, je
## Glied {"face": int, "value": int (rohe Augen), "material": String, "level": int}.
## NUR die Kehrseiten-Rune - einmal nach allen Würfel-Triggern. Der Aufrufer löst
## sie EINMAL auf (scene_root kennt Defs + obere Seiten), so sehen Vorschau,
## Nehmen und Farkle-Vergleich dieselben Glieder.
const CTX_DET_LINKS := "det_links"

## Essenz-Glieder (ctx-Schlüssel): dieselbe Form, aber JE WÜRFEL-TRIGGER einmal
## gefeuert - das Röntgenlicht belichtet bei jedem Antritt.
const CTX_ESSENCE_LINKS := "essence_links"

## Deterministische Glieder des Slots aus dem ctx ([] = keine).
static func det_links_for(ctx: Dictionary, slot: int) -> Array:
	var links: Dictionary = ctx.get(CTX_DET_LINKS, {})
	return links.get(slot, [])

## Die Essenz-Glieder eines Slots, aufgeteilt auf die Würfel-Trigger: je Antritt
## die Glieder dieses Antritts (Manometer wiederholt sie). Die Werte wandern über
## die ganze Reihe weiter, wie im eingefrorenen Pointer-Wurf - ein Knochen-Glied
## zählt beim zweiten Antritt den gewachsenen Wert, und genau dort landet auch die
## Def, weil apply_take_effects dieselbe Zahl von Zündungen läuft.
static func essence_link_groups(ctx: Dictionary, slot: int, die_triggers: int, repeat: int,
		charm_ids: Array[String], essence_ids: Array[String], clause_growth: int = 0) -> Array:
	var links: Dictionary = ctx.get(CTX_ESSENCE_LINKS, {})
	var base: Array = links.get(slot, [])
	var groups: Array = []
	if base.is_empty():
		return groups
	var running := {}
	for _t in maxi(0, die_triggers):
		var group: Array = []
		for _r in maxi(1, repeat):
			for link: Dictionary in base:
				var face := int(link["face"])
				var value: int = running.get(face, int(link["value"]))
				var entry := link.duplicate()
				entry["value"] = value
				group.append(entry)
				running[face] = MaterialEffects.mutate_link_value_once(value, String(link["material"]),
					charm_ids, int(link.get("raw_level", link.get("level", 1))), essence_ids, clause_growth)
		groups.append(group)
	return groups

## Die Essenz-Glieder EINES Würfel-Triggers ([] = keine).
static func essence_links_at(groups: Array, trigger_index: int) -> Array:
	return groups[trigger_index] if trigger_index >= 0 and trigger_index < groups.size() else []

## Dieselben Glieder, aber so oft, wie die Seele wirkt (Manometer). Die Werte
## wandern dabei weiter wie im eingefrorenen Pointer-Wurf - ein Knochen-Glied
## zählt beim zweiten Durchlauf den gewachsenen Wert, und genau dort landet auch
## die Def, weil apply_take_effects dieselbe Zahl von Zündungen läuft.
static func repeated_det_links(ctx: Dictionary, slot: int, repeat: int,
		charm_ids: Array[String], essence_ids: Array[String], clause_growth: int = 0) -> Array:
	var links := det_links_for(ctx, slot)
	if repeat <= 1 or links.is_empty():
		return links
	var out: Array = []
	var running := {}
	for _r in repeat:
		for link: Dictionary in links:
			var face := int(link["face"])
			var material := String(link["material"])
			var value: int = running.get(face, int(link["value"]))
			var entry := link.duplicate()
			entry["value"] = value
			out.append(entry)
			# Gewandelt wird mit dem ECHTEN Zustand der Seite - "level" trägt den
			# Firnis-Aufschlag, der nur die Wertung hebt, nie die Def.
			running[face] = MaterialEffects.mutate_link_value_once(value, material,
				charm_ids, int(link.get("raw_level", link.get("level", 1))), essence_ids, clause_growth)
	return out

## Gezündete Pointer (ctx-Schlüssel): Dictionary Slot -> Array über die
## WÜRFEL-Trigger, je Trigger die Liste der gezündeten Glieder (leer = der Wurf
## ist danebengegangen). Einträge wie bei den Essenz-Gliedern.
## Der Pointer ist die einzige Zufallsquelle der Wertung: er wird beim Nehmen
## EINMAL ausgewürfelt (roll_pointer_fires) und hier eingefroren, damit Wertung,
## Schrittliste und Nehmen-Effekte dieselben Zündungen sehen. Der VORSCHAU fehlt
## der Schlüssel - sie zeigt die Hand ohne Pointer.
const CTX_POINTER_FIRES := "pointer_fires"

## Alle Trigger-Gruppen des Slots ([] = nichts gezündet).
static func pointer_fires_for(ctx: Dictionary, slot: int) -> Array:
	var fires: Dictionary = ctx.get(CTX_POINTER_FIRES, {})
	return fires.get(slot, [])

## Die Glieder, die im Würfel-Trigger trigger_index gezündet haben.
static func pointer_fires_at(ctx: Dictionary, slot: int, trigger_index: int) -> Array:
	var groups := pointer_fires_for(ctx, slot)
	return groups[trigger_index] if trigger_index >= 0 and trigger_index < groups.size() else []

## Material-Zustände (ctx-Schlüssel): Dictionary Slot -> {"level": int (0 keins,
## 1 normal, 2 veredelt - das Material der OBEREN Seite), "eye_sum": int}. Wie die
## Essenz-Glieder löst der Aufrufer das EINMAL auf.
const CTX_MATERIAL_LEVELS := "material_levels"

## Material-Infos des Slots aus dem ctx ({} = normal, siehe MaterialEffects.level_in).
static func level_info_for(ctx: Dictionary, slot: int) -> Dictionary:
	var levels: Dictionary = ctx.get(CTX_MATERIAL_LEVELS, {})
	return levels.get(slot, {})

## Essenzen (ctx-Schlüssel): Dictionary Slot -> Essenz-id ("" = keine). Wie die
## Essenz-Glieder löst der Aufrufer das EINMAL auf, damit Vorschau, Nehmen
## und Farkle-Vergleich dieselben Würfel beseelt sehen.
const CTX_ESSENCES := "essences"

## Phosphoreszenz-Speicher (ctx-Schlüssel): Dictionary Slot -> gespeicherte
## Basispunkte bzw. gespeicherter Mult (Leuchtstoffröhre). Zustand am Würfel-
## Exemplar, den nur GameRun führt - er überlebt die Runde und wächst mit jeder
## Wertung; die Wertung legt ihn nur obendrauf, gebucht wird beim Nehmen.
const CTX_PHOSPHOR_STORE := "phosphor_store"
const CTX_PHOSPHOR_MULT := "phosphor_mult"

## Auslösungen und Krits der BISHERIGEN Hände dieser Runde (ctx-Schlüssel).
## Rundenzustand aus GameRun; gelesen wird er nur, wenn Dunkelkammer bzw.
## Gewitterfront im Dock stehen (EssenceEffects.round_*_offset).
const CTX_ROUND_TRIGGERS := "round_triggers"
const CTX_ROUND_CRITS := "round_crits"

## Hand-weiter Lauf-/Rundenzustand (ctx-Schlüssel, alle int): gelagerte Energie
## (Tscherenkow, Standby-Licht), Rundennummer (Kilometerzähler), schon genommene
## Hände dieser Runde (Mitternachtssonne), Fumbles der Runde plus der run-lange
## Vulkanblitz-Zähler (Aschewolke) und die Zahl der beseelten Würfel in der ABLAGE
## (Flaschenregal - gezählt werden Würfel, nicht Sorten).
const CTX_ENERGY := "energy"
const CTX_ROUND := "round_number"
const CTX_HANDS_TAKEN := "hands_taken"
const CTX_FUMBLES := "round_fumbles"
const CTX_ASH_FUMBLES := "ash_fumbles"
const CTX_DISCARD_SOULS := "discard_souls"

## Augen der Ablage (ctx-Schlüssel): die OBEN liegenden Werte aller abgelegten
## Würfel dieser Runde, in Ablage-Reihenfolge. Live aus den Defs gebildet, damit
## spätere Wertwandel durchschlagen (Fuchsfeuer, Pilzgeflecht).
const CTX_DISCARD_VALUES := "discard_values"

## Erstwertung (ctx-Schlüssel): Slot -> hat dieser Würfel in DIESER Runde noch
## nicht gewertet. Slot-gebunden, also umgeschlüsselt und für den Farkle-Vergleich
## mitgeschnappt (Sternschnuppe, Gammablitz).
const CTX_FIRST_SCORING := "first_scoring"

## Wertet dieser Slot in dieser Runde zum ersten Mal?
static func first_scoring_for(ctx: Dictionary, slot: int) -> bool:
	var flags: Dictionary = ctx.get(CTX_FIRST_SCORING, {})
	return bool(flags.get(slot, false))

## Die oben liegenden Werte der Ablage ([] = leere Ablage).
static func discard_values_in(ctx: Dictionary) -> Array[int]:
	var out: Array[int] = []
	out.assign(ctx.get(CTX_DISCARD_VALUES, []))
	return out

## Fumbles, mit denen der Vulkanblitz kritet: die dieser Runde, mit Aschewolke
## dazu der run-lange Zähler.
static func volcanic_fumbles_in(ctx: Dictionary, charm_ids: Array[String]) -> int:
	var fumbles := int(ctx.get(CTX_FUMBLES, 0))
	if charm_ids.has(Charm.ASH_CLOUD):
		fumbles += int(ctx.get(CTX_ASH_FUMBLES, 0))
	return maxi(0, fumbles)

## Pointer-Würfe, die danebengegangen sind (Erdungskabel): je Würfel-Trigger
## eine leere Gruppe. Im ctx stehen nur Würfel, die überhaupt einen Pointer
## tragen - ein leerer Eintrag IST also ein Fehlwurf.
static func pointer_misses_in(ctx: Dictionary) -> int:
	var misses := 0
	var fires: Dictionary = ctx.get(CTX_POINTER_FIRES, {})
	for slot in fires:
		for group: Array in fires[slot]:
			if group.is_empty():
				misses += 1
	return misses

## Wirksame Essenz-Mengen (ctx-Schluessel): Slot -> Array der Essenz-ids, die an
## diesem Wuerfel WIRKEN. Normal genau die eigene; die Quintessenz borgt sich die
## der anderen liegenden Wuerfel dazu (siehe EssenceEffects.effective_sets).
const CTX_ESSENCE_SET := "essence_sets"

## Gleichschliff (ctx-Schlüssel): Slot -> die Zahl, die auf ALLEN SECHS Seiten
## steht (0 = nicht einheitlich). Aus den Defs gelesen, weil die Hooks die Würfel
## nicht kennen; slot-gebunden, also umgeschlüsselt. Bedingung UND Betrag stehen
## damit bei Handbeginn fest - ein mitten in der Zählung gewachsener Knochen kippt
## sie nicht (Zielwahl bleibt gepinnt, die stehende Regel).
const CTX_EQUAL_FACES := "equal_faces"

static func equal_faces_for(ctx: Dictionary, slot: int) -> int:
	var faces: Dictionary = ctx.get(CTX_EQUAL_FACES, {})
	return int(faces.get(slot, 0))

## Stresstest-Flagge (ctx-Schlüssel): das Elmsfeuer glüht dort vierfach.
const CTX_STRESS := "stress_round"

## Material-Seiten des GANZEN Würfelpools (ctx-Schlüssel, int): Laufzustand, den
## die reine Wertung nicht kennt - nur die Inventur liest ihn. Hand-weit, also
## ohne Umschlüsselung.
const CTX_POOL_MATERIALS := "pool_materials"

## Klausel-Wachstum (ctx-Schlüssel, hand-weit): die Kaltverfestigung lässt JEDE
## ausgelöste Seite um so viele Augen wachsen. Hand-weit, also ohne Umschlüsselung.
const CTX_CLAUSE_GROWTH := "clause_growth"

static func clause_growth_in(ctx: Dictionary) -> int:
	return maxi(0, int(ctx.get(CTX_CLAUSE_GROWTH, 0)))

## Runen (ctx-Schlüssel): Dictionary Slot -> Liste der Runen-ids auf der OBEN
## liegenden Seite. Wie die Essenz-Glieder löst der Aufrufer das EINMAL auf;
## das Nachglühen ändert Auslösungen, also braucht auch der Farkle-Vergleich die
## alten Runen.
const CTX_RUNES := "runes"

## Vom Spieler in der Grube gelegte Zählreihenfolge (Array von Slot-Indizes).
## Eine ANSAGE, kein Messwert: die Reihe wird aus diesem Array gerendert, nie
## umgekehrt aus den Würfelpositionen gelesen - nur so sind Vorschau, Zug,
## Farkle-Vergleich und Zähl-Animation garantiert derselben Meinung.
const CTX_PLAYER_ORDER := "player_order"
## Rang eines Würfels, den die Ansage nicht nennt.
const UNRANKED := 1 << 30

static func runes_in(ctx: Dictionary) -> Dictionary:
	return ctx.get(CTX_RUNES, {})

static func runes_for(ctx: Dictionary, slot: int) -> Array[String]:
	return RuneEffects.runes_at(runes_in(ctx), slot)

static func essences_in(ctx: Dictionary) -> Dictionary:
	return ctx.get(CTX_ESSENCES, {})

## Wirksame Essenz-MENGEN je Slot (die Quintessenz borgt sich fremde Seelen).
## Fehlt der Schluessel, wird er aus CTX_ESSENCES abgeleitet - so bleiben
## Aufrufer gueltig, die nur die eigenen Essenzen mitgeben.
static func essence_sets_in(ctx: Dictionary) -> Dictionary:
	if ctx.has(CTX_ESSENCE_SET):
		return ctx[CTX_ESSENCE_SET]
	return EssenceEffects.effective_sets(essences_in(ctx))

## Gespeicherte Basispunkte des Slots (Phosphoreszenz; 0 = leer).
static func phosphor_store_for(ctx: Dictionary, slot: int) -> int:
	var store: Dictionary = ctx.get(CTX_PHOSPHOR_STORE, {})
	return int(store.get(slot, 0))

## Gespeicherter Mult des Slots (Phosphoreszenz + Leuchtstoffröhre; 0 = leer).
static func phosphor_mult_for(ctx: Dictionary, slot: int) -> float:
	var store: Dictionary = ctx.get(CTX_PHOSPHOR_MULT, {})
	return float(store.get(slot, 0.0))

## Die GEZEIGTEN Werte: erst die Charm-Verwandlungskette, dann die Essenz-Linse
## (Wasserstoff verdoppelt). Alles, was erkennt, ordnet oder zielt, rechnet auf
## ihnen; der physische Wert (raw) bleibt davon unberührt.
static func shown_values(dice: Array[int], charm_ids: Array[String], ctx: Dictionary = {}) -> Array[int]:
	var sets := essence_sets_in(ctx)
	if sets.is_empty():
		return CharmEffects.shown_by_charms_all(dice, charm_ids)
	var out: Array[int] = []
	for i in dice.size():
		out.append(shown_value(dice[i], charm_ids, EssenceEffects.set_at(sets, i)))
	return out

## Gezeigter Wert EINER Seite - dieselbe Reihenfolge wie shown_values.
static func shown_value(value: int, charm_ids: Array[String], essence_ids: Array[String]) -> int:
	return EssenceEffects.lens_value_of(essence_ids, CharmEffects.shown_by_charms(value, charm_ids))

## Anzeige-Beispiele der Kombinationsliste; per Test gegen die echte Wertung
## geprüft (best_hand(Beispiel) muss genau seine Kategorie liefern).
const EXAMPLE_DICE := {
	ONE_KIND: [6],
	TWO_KIND: [6, 6],
	TWO_PAIR: [6, 6, 5, 5],
	THREE_KIND: [6, 6, 6],
	SMALL_STRAIGHT: [1, 2, 3, 4, 5],
	FOUR_KIND: [6, 6, 6, 6],
	FULL_HOUSE: [6, 6, 6, 1, 1],
	THREE_PAIRS: [6, 6, 5, 5, 4, 4],
	DOUBLE_THREE_KIND: [6, 6, 6, 5, 5, 5],
	FOUR_KIND_AND_PAIR: [6, 6, 6, 6, 1, 1],
	LARGE_STRAIGHT: [1, 2, 3, 4, 5, 6],
	FIVE_KIND: [6, 6, 6, 6, 6],
	SIX_KIND: [6, 6, 6, 6, 6, 6],
}

static func label_for(key: String) -> String:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["label"]
	return key

## Jede Übertaktungs-Stufe addiert den autorierten mult_step der Kategorie.
static func mult_for(key: String, combo_levels: Dictionary = {}) -> int:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["mult"] + cat["mult_step"] * int(combo_levels.get(key, 0))
	return 1

## Feste Basispunkte ("Chips") - skalieren mit Menü-Stufen wie mult_for.
static func points_for(key: String, combo_levels: Dictionary = {}) -> int:
	for cat in CATEGORIES:
		if cat["key"] == key:
			return cat["points"] + cat["points_step"] * int(combo_levels.get(key, 0))
	return 0

## Der Joker-Slot (Polarlicht) oder -1. Legendär und damit Unikat: es kann NIE
## mehr als einen geben, darum genügt EIN Index statt einer Liste.
static func wild_slot(ctx: Dictionary) -> int:
	var essences := essences_in(ctx)
	for slot in essences:
		if EssenceEffects.is_wild(EssenceEffects.essence_at(essences, int(slot))):
			return int(slot)
	return -1

## Die Zahl, zu der sich der Joker (Polarlicht) für diese Kategorie macht - 0,
## wenn keiner mitspielt oder keine Belegung trägt. Dieselbe Wahl wie
## participating_indices: der höchste Wert, der die Kategorie hält. Nur der
## Polarfilter fragt danach, er kritet mit ihr.
static func wild_value(key: String, shown: Array[int], ctx: Dictionary, charm_ids: Array[String] = []) -> int:
	var legal := legal_indices(shown, ctx)
	var wild := _wild_index_in(legal, ctx)
	if wild < 0:
		return 0
	var sub := (shown if legal.size() == shown.size() else _legal_dice(shown, legal)).duplicate()
	for value in range(6, 0, -1):
		sub[wild] = value
		if _qualifies_plain(key, sub, charm_ids):
			return value
	return 0

## Position des Jokers INNERHALB der gefilterten Liste (-1, wenn er gar nicht
## mitspielt - der Paritätsfilter urteilt über seine AUFGEDRUCKTE Zahl).
static func _wild_index_in(legal: Array[int], ctx: Dictionary) -> int:
	var slot := wild_slot(ctx)
	return legal.find(slot) if slot >= 0 else -1

## Trifft die Kategorie zu? Mit Joker wird jede Belegung durchprobiert - die
## Ersetzung passiert NUR hier in der Erkennung, nach dem legalen Filter.
## charm_ids: nur die Zahnlücke greift in die Erkennung ein (Straße mit Loch).
static func qualifies(key: String, dice: Array[int], ctx: Dictionary = {}, charm_ids: Array[String] = []) -> bool:
	var legal := legal_indices(dice, ctx)
	var sub := dice if legal.size() == dice.size() else _legal_dice(dice, legal)
	var wild := _wild_index_in(legal, ctx)
	if wild < 0:
		return _qualifies_plain(key, sub, charm_ids)
	for value in range(6, 0, -1):
		var variant := sub.duplicate()
		variant[wild] = value
		if _qualifies_plain(key, variant, charm_ids):
			return true
	return false

static func _qualifies_plain(key: String, dice: Array[int], charm_ids: Array[String] = []) -> bool:
	match key:
		SIX_KIND:
			return _has_count_at_least(dice, 6)
		FIVE_KIND:
			return _has_count_at_least(dice, 5)
		LARGE_STRAIGHT:
			return _has_straight_of_length(dice, 6, charm_ids)
		FOUR_KIND_AND_PAIR:
			return _has_count_and_other_count(dice, 4, 2)
		DOUBLE_THREE_KIND:
			return _has_two_groups_with_at_least(dice, 3)
		THREE_PAIRS:
			return _count_groups_with_at_least(dice, 2) >= 3
		FOUR_KIND:
			return _has_count_at_least(dice, 4)
		FULL_HOUSE:
			return _has_count_and_other_count(dice, 3, 2)
		SMALL_STRAIGHT:
			return _has_straight_of_length(dice, 5, charm_ids)
		THREE_KIND:
			return _has_count_at_least(dice, 3)
		TWO_PAIR:
			return _count_groups_with_at_least(dice, 2) >= 2
		TWO_KIND:
			return _has_count_at_least(dice, 2)
		ONE_KIND:
			return not dice.is_empty()  # ohne legalen Würfel zählt auch die Rückfall-Kategorie nicht
	return false

## Wertet eine Kategorie in FESTER Trigger-Reihenfolge (keine Ausnahmen):
## Würfel in Reihen-Ordnung (trigger_order; je Zündung Augen, Material,
## würfelgebundene Charms - Knochen/Glas wandeln den Wert zwischen den
## Zündungen; je Würfel-Trigger danach der gewürfelte Pointer, zuletzt die
## Essenz-Glieder), dann
## statische Charms strikt in Besitz-Reihenfolge (Boni UND Krits an ihrer
## Position), zuletzt das EINE Verschmelzen. materials: DieMaterial-id je Slot
## ("" = keins). ctx: Wurf-/Runden-Zustand - dort steht auch, die wievielte Hand
## der Runde das ist (die Zauberkarte fragt danach).
static func score_category(key: String, dice: Array[int], charm_ids: Array[String] = [], _is_first_hand: bool = false, materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> int:
	# raw = die PHYSISCHEN Seitenwerte; nur auf ihnen läuft der Wertwandel
	# (Knochen/Glas/Helium), damit die Wertung genau dort landet, wo die Def landet.
	var raw := dice
	dice = shown_values(dice, charm_ids, ctx)
	if is_throttled(key, ctx) or not qualifies(key, dice, ctx, charm_ids):
		return 0
	var pair := _base_and_mult(key, dice, raw, charm_ids, materials, combo_levels, ctx)
	# Die EINZIGE Rundung der ganzen Rechnung: erst beim Verschmelzen, und
	# aufgerundet. Zwei ×1,5 müssen ×2,25 ergeben, nie zweimal ×2.
	return ceili(float(pair[0]) * maxf(1.0, pair[1]))

## Kompletter Kombi-Multiplikator - die Mult-Seite derselben Rechnung; min. 1.
## Eine Quelle für Rechnung UND Anzeige.
static func _total_mult(key: String, dice: Array[int], charm_ids: Array[String], materials: Array[String], combo_levels: Dictionary, ctx: Dictionary) -> float:
	var raw := dice
	dice = shown_values(dice, charm_ids, ctx)
	return maxf(1.0, _base_and_mult(key, dice, raw, charm_ids, materials, combo_levels, ctx)[1])

## Zählreihenfolge der Würfelphase: die Reihe, wie sie beim Nehmen aufgereiht
## liegt - KOMBINATIONS-ERST. Die Kombinationswürfel bilden Blöcke je
## Kombinationsziffer; die Blöcke stehen nach GRÖSSE absteigend, bei gleicher
## Größe nach Ziffer absteigend, innerhalb eines Blocks nach gezeigtem Wert
## absteigend und bei Gleichstand kleinster Slot zuerst. Dahinter die bloß
## MITGEWERTETEN (Vollzähler, Krypton) nach derselben Wert/Slot-Regel.
## So bleibt eine Gruppe beisammen: ein Full House zählt 3-3-3-5-5, nie 5-5-3-3-3.
## Deterministisch aus den Werten, damit Vorschau, Wertung und Grubenanimation
## identisch laufen (die Ordnung ist wertungsrelevant: Echo-Kammer, Wasserfall,
## Stroboskop, Miasma, Radon).
## declared = die vom Spieler in der Grube gelegte Reihenfolge (Slot-Indizes).
## Ist sie leer, gilt die kanonische Regel; liegt sie an, ERSETZT sie diesen
## Rang: die Anordnung der Hand ist eine Ansage des Spielers, keine Ableitung
## aus der Physik. Keine Essenz greift mehr in die Reihenfolge ein.
## participating = die Kombinationswürfel. Ohne sie (ältere Aufrufer) gibt es
## keine Blöcke und die Reihe fällt auf die reine Wert-Ordnung zurück.
static func trigger_order(scored: Array[int], dice: Array[int], declared: Array = [], participating: Array[int] = []) -> Array[int]:
	var order := scored.duplicate()
	var rank := {}
	for i in declared.size():
		rank[int(declared[i])] = i
	var block_rank := _block_ranks(dice, participating)
	order.sort_custom(func(a: int, b: int) -> bool:
		if not rank.is_empty():
			# Nicht angesagte Würfel hängen sich hinten an und sortieren sich
			# untereinander wieder kanonisch (gleicher Platzhalter-Rang).
			var ra: int = rank.get(a, UNRANKED)
			var rb: int = rank.get(b, UNRANKED)
			if ra != rb:
				return ra < rb
		var ba: int = block_rank.get(a, UNRANKED)
		var bb: int = block_rank.get(b, UNRANKED)
		if ba != bb:
			return ba < bb
		return dice[a] > dice[b] or (dice[a] == dice[b] and a < b))
	return order

## Slot -> Rang seines Kombinations-Blocks (0 = vorderster). Blöcke nach Größe
## absteigend, bei gleicher Größe nach Kombinationsziffer absteigend; der
## Gleichstand muss AUSDRÜCKLICH brechen, sort_custom ist nicht stabil.
static func _block_ranks(dice: Array[int], participating: Array[int]) -> Dictionary:
	var ranks := {}
	if participating.is_empty():
		return ranks
	var members := {}
	for slot in participating:
		if slot < 0 or slot >= dice.size():
			continue
		var digit := _digit(dice[slot])
		if not members.has(digit):
			members[digit] = [] as Array[int]
		members[digit].append(slot)
	var digits: Array[int] = []
	digits.assign(members.keys())
	digits.sort_custom(func(a: int, b: int) -> bool:
		var sa: int = (members[a] as Array).size()
		var sb: int = (members[b] as Array).size()
		if sa != sb:
			return sa > sb
		return a > b)
	for k in digits.size():
		for slot: int in members[digits[k]]:
			ranks[slot] = k
	return ranks

# --- Pointer: eine Chance, EINMAL ausgewürfelt -------------------------------

## Grundchance, mit der ein Pointer je Wurf zündet.
const POINTER_CHANCE := 0.5
## Lötkolben: +10 Prozentpunkte auf die GRUNDCHANCE je Exemplar - gedeckelt,
## denn ein Pointer, der sicher zündet, wäre keine Chance mehr.
const SOLDERING_IRON_BONUS := 0.1
const POINTER_CHANCE_MAX := 0.95
## Harte Schranke gegen pathologisches RNG (2^-32); Ketten dürfen kreisen.
const POINTER_HOP_CAP := 32

## Grundchance nach den Charms - VOR der Plasma-Aggregation, die auf ihr aufsetzt.
static func pointer_base_chance(charm_ids: Array[String]) -> float:
	return minf(POINTER_CHANCE_MAX,
		POINTER_CHANCE + SOLDERING_IRON_BONUS * float(charm_ids.count(Charm.SOLDERING_IRON)))

## Aggregierte Chance über firings Seiten-Zündungen: 1 − (1−p)^n. Ein Würfel-
## Trigger würfelt EINMAL mit ihm statt je Zündung neu - so bleibt der Pointer
## auch bei vielen Zündungen bei höchstens einer Kette je Trigger.
static func pointer_chance_for(chance: float, firings: int) -> float:
	return 1.0 - pow(1.0 - clampf(chance, 0.0, 1.0), float(maxi(1, firings)))

## Würfelt die Pointer EINES Würfels für die ganze Hand aus: je Würfel-Trigger
## ein Wurf mit der aggregierten Chance; ein Treffer zündet die Zielseite EINMAL
## (die Seiten-Achse gilt dort nicht - Runen gehören der oberen Seite). Trägt die
## gezündete Seite selbst einen Pointer, geht es Sprung für Sprung mit der
## EINFACHEN Chance weiter; ein Zyklus würfelt einfach weiter.
## Die Werte wandern mit: eine zweimal gezündete Knochen-Seite zählt beim zweiten
## Mal den gewachsenen Wert. Gerechnet wird mit dem ECHTEN Zustand - genau diese
## Zahl landet später in der Def, der Firnis hebt nur die Wertung.
static func roll_pointer_fires(die: DieDefinition, up_face: int, die_triggers: int, face_triggers: int,
		charm_ids: Array[String], essence_ids: Array[String], rng: RandomNumberGenerator,
		essence_repeat: int = 1, clause_growth: int = 0) -> Array:
	var groups: Array = []
	if die == null or up_face < 0 or up_face >= 6 or rng == null:
		return groups
	var chance := EssenceEffects.pointer_chance_of(essence_ids, pointer_base_chance(charm_ids))
	var aggregated := pointer_chance_for(chance, face_triggers)
	# Wie oft ein gezündetes Glied seine Zielseite feuert (Glasfaser, Zündspule) -
	# eingefroren wie jede andere Zündung, damit Wertung, Schrittliste und
	# Nehmen-Effekte dieselbe Liste lesen.
	var shots := EssenceEffects.link_fire_count(essence_ids, charm_ids)
	# Laufende Werte JEDER Seite - auch die obere wandert mit, denn eine Kette darf
	# auf sie zurückspringen.
	var running: Array[int] = die.faces.duplicate()
	var up_material: String = die.materials[up_face] if up_face < die.materials.size() else ""
	var up_level := MaterialEffects.face_level(die, up_face)
	var up_runes := die.runes_on(up_face)
	for _t in maxi(1, die_triggers):
		for _f in maxi(1, face_triggers):
			running[up_face] = MaterialEffects.mutate_value_once(running[up_face], up_material,
				charm_ids, up_level, essence_ids, up_runes, essence_repeat, clause_growth)
		var fires: Array[Dictionary] = []
		var face := up_face
		var roll_chance := aggregated
		for _hop in POINTER_HOP_CAP:
			var target := die.pointer_target(face)
			if target < 0 or rng.randf() >= roll_chance:
				break
			var material: String = die.materials[target] if target < die.materials.size() else ""
			var level := MaterialEffects.face_level(die, target)
			for _shot in shots:
				fires.append({
					"face": target,
					"value": running[target],
					"material": material,
					"level": EssenceEffects.boosted_level(level, essence_ids),
				})
				running[target] = MaterialEffects.mutate_link_value_once(running[target], material,
					charm_ids, level, essence_ids, clause_growth)
			face = target
			roll_chance = chance
		groups.append(fires)
	return groups

## Der Vorspann jeder Wertung: die gewertete Menge, ihre Zählreihenfolge und der
## Echo-Slot. EINE Quelle für _base_and_mult, ScoreBreakdown und den Pointer-
## Wurf - sonst würfelte der Wurf andere Achsen aus, als die Wertung zählt.
static func hand_shape(key: String, raw: Array[int], charm_ids: Array[String], ctx: Dictionary) -> Dictionary:
	var dice := shown_values(raw, charm_ids, ctx)
	var participating := participating_indices(key, raw, charm_ids, ctx)
	# Vollzähler weitet die gewertete Menge auf ALLE liegenden Würfel; sonst zählen
	# nur die beteiligten. Kombi-Charms (Snake Eyes & Co.) bleiben auf participating.
	var scored := CharmEffects.scored_indices(participating, dice.size(), charm_ids)
	# Auch der Vollzähler zieht keine paritätsgesperrten Würfel herein.
	var legal := legal_indices(dice, ctx)
	if legal.size() < dice.size():
		var allowed: Array[int] = []
		for i in scored:
			if legal.has(i):
				allowed.append(i)
		scored = allowed
	# Krypton zählt IMMER mit - auch außerhalb der Kombination. Er wächst nur in
	# die gewertete Menge, nie in participating: die Erkennung und die Kombi-Charms
	# bleiben unberührt (dieselbe Trennung wie beim Vollzähler).
	var sets := essence_sets_in(ctx)
	if not sets.is_empty():
		var extra: Array[int] = []
		for i in legal:
			if not scored.has(i) and EssenceEffects.always_scored_of(sets, i):
				extra.append(i)
		if not extra.is_empty():
			# Nie in place: ohne Vollzähler IST scored dieselbe Liste wie participating.
			var widened: Array[int] = scored.duplicate()
			widened.append_array(extra)
			widened.sort()
			scored = widened
	var order := trigger_order(scored, dice, ctx.get(CTX_PLAYER_ORDER, []), participating)
	return {
		"dice": dice,
		"participating": participating,
		"scored": scored,
		"order": order,
		# "Zuerst gewertet" heißt KOPF DER REIHE, nicht kleinster Slot - eine
		# gelegte Ansage verschiebt Echo-Kammer und Vorreiter also mit.
		"echo_slot": order[0] if not order.is_empty() else -1,
		# Schlusslicht der Reihe (Rücklicht). Bei einem einzigen Würfel ist er
		# beides und bekommt beide Zugaben.
		"tail_slot": order[order.size() - 1] if not order.is_empty() else -1,
	}

## Slots der Reihe, die insgesamt GENAU EINMAL zünden (Würfel-Achse × Seiten-
## Achse). Nur das Metronom fragt danach - ein zustandsloser die_charm_*-Hook
## kann die Auslösungen der Mitwürfel nicht kennen, also läuft die Vorabrunde,
## und auch nur dann.
static func single_trigger_slots(order: Array[int], dice: Array[int], charm_ids: Array[String], ctx: Dictionary, echo_slot: int, tail_slot: int, participating: Array[int] = []) -> Array[int]:
	var singles: Array[int] = []
	var essences := essence_sets_in(ctx)
	var runes := runes_in(ctx)
	var is_stress := bool(ctx.get(CTX_STRESS, false))
	var hands_taken := int(ctx.get(CTX_HANDS_TAKEN, 0))
	for i in order:
		var essence_ids := EssenceEffects.set_at(essences, i)
		var die_triggers := MaterialEffects.die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
			EssenceEffects.extra_activations(i, order, essences, charm_ids, dice, hands_taken), order.size(), tail_slot,
			hands_taken == 0, participating.has(i))
		var face_triggers := MaterialEffects.face_trigger_count(dice[i], charm_ids,
			RuneEffects.extra_activations(RuneEffects.runes_at(runes, i), charm_ids), essence_ids)
		if die_triggers * face_triggers == 1:
			singles.append(i)
	return singles

## Basis und Mult einer Hand in der festen Trigger-Reihenfolge (dice = die
## GEZEIGTEN Werte, raw = die physischen Seitenwerte). [int base, float mult] -
## mult ungeklemmt und ungerundet; gerundet wird erst beim Verschmelzen.
static func _base_and_mult(key: String, dice: Array[int], raw: Array[int], charm_ids: Array[String], materials: Array[String], combo_levels: Dictionary, ctx: Dictionary) -> Array:
	var shape := hand_shape(key, raw, charm_ids, ctx)
	var participating: Array[int] = shape["participating"]
	var scored: Array[int] = shape["scored"]
	var echo_slot: int = shape["echo_slot"]
	var tail_slot: int = shape["tail_slot"]
	# Acetylen und Schneidbrenner hängen beide an der Übertaktungs-Stufe.
	var combo_level := int(combo_levels.get(key, 0))
	# Dreifacher Boden vervielfacht NUR die Basispunkte der Kombination -
	# points_for/mult_for selbst bleiben die reine Stufe (Chips, Preise, Vorschauen).
	var combo_factor := CharmEffects.combo_factor(charm_ids)
	var base := points_for(key, combo_levels) * combo_factor
	var mult := float(mult_for(key, combo_levels))
	var essences := essence_sets_in(ctx)
	var runes := runes_in(ctx)
	var is_stress := bool(ctx.get(CTX_STRESS, false))
	# Krits dieser Hand, laufend gezählt: Ozon wächst mit ihnen, das Grubengas legt
	# je Krit davor +20 Basis auf SEINE Zündung. Die Gewitterfront startet den
	# Zähler beim Stand der Runde statt bei null.
	var crits := EssenceEffects.round_crit_offset(charm_ids, int(ctx.get(CTX_ROUND_CRITS, 0)))
	# Laufender Auslösungszähler der ganzen Hand (Pointer-Glieder zählen mit):
	# das Photonengas sammelt das Licht aller Auslösungen vor sich - mit
	# Dunkelkammer auch das der bisherigen Hände der Runde.
	var triggers := EssenceEffects.round_trigger_offset(charm_ids, int(ctx.get(CTX_ROUND_TRIGGERS, 0)))
	# Einmal je Hand bestimmt, wie der Grubengas-Schritt: der Blitzableiter-
	# Zuschlag darf sich mitten in der Zählung nicht ändern.
	var ball_bonus := EssenceEffects.ball_crit_bonus(scored, essences, charm_ids)
	# Polarfilter: der Joker kritet mit der Zahl, zu der er sich macht.
	var wild := wild_slot(ctx) if charm_ids.has(Charm.POLARIZER) else -1
	var wild_eyes := wild_value(key, dice, ctx, charm_ids) if wild >= 0 else 0
	# Lauf- und Rundenzustand der dritten Welle: einmal je Hand gelesen, damit
	# sich kein Krit mitten in der Zählung verschiebt.
	# Laufender REST der Energie: der Tscherenkow verbrennt je Schlag eine.
	var energy := maxi(0, int(ctx.get(CTX_ENERGY, 0)))
	var hands_taken := int(ctx.get(CTX_HANDS_TAKEN, 0))
	var volcanic := volcanic_fumbles_in(ctx, charm_ids)
	var discard_values := discard_values_in(ctx)
	# Auch ohne Materialien können Charms und Essenzen Aktivierungen stapeln.
	var has_die_bonus := not materials.is_empty() or not charm_ids.is_empty() \
		or not essences.is_empty() or not runes.is_empty()
	var order: Array[int] = shape["order"]
	# Kaltverfestigung: hand-weit, jede Zündung legt ihr Auge auf die Seite.
	var clause_growth := clause_growth_in(ctx)
	# LAUFENDE Werte der GANZEN Hand, nicht je Würfel: die Ansteckung (Miasma)
	# schiebt Augen quer über die Reihe, ein später zählender Würfel zählt also
	# schon den gewachsenen Wert.
	var running_values: Array[int] = []
	for i in dice.size():
		running_values.append(raw[i] if i < raw.size() else dice[i])
	# Wasserfall: die zuletzt AUSLÖSENDE Augenzahl, über die ganze Hand fortgeschrieben.
	var cascade_last := CharmEffects.CASCADE_UNSET
	# Metronom: die einmal zündenden Würfel stehen VOR der Zählung fest.
	var singles: Array[int] = []
	if charm_ids.has(Charm.METRONOME):
		singles = single_trigger_slots(order, dice, charm_ids, ctx, echo_slot, tail_slot, participating)
	# Würfelphase in Reihen-Ordnung. ZWEI Achsen: der Würfel tritt die_triggers-mal
	# an, je Antritt zündet die obere Seite face_triggers-mal; je Zündung Augen ->
	# Material -> würfelgebundene Charms (additiv, dann Krits) - siehe CharmEffects-Kopf.
	for i in order:
		var info := level_info_for(ctx, i)
		var level := MaterialEffects.level_in(info)
		var eye_sum := int(info.get("eye_sum", 0))
		var face_material: String = materials[i] if i < materials.size() else ""
		var essence_ids := EssenceEffects.set_at(essences, i)
		var rune_ids := RuneEffects.runes_at(runes, i)
		# Phosphoreszenz kippt ihren Speicher als eigenen Basis-Eintrag aus - mit
		# Leuchtstoffröhre dazu den gespeicherten Mult.
		base += phosphor_store_for(ctx, i)
		mult += phosphor_mult_for(ctx, i)
		var die_triggers := 1
		var face_triggers := 1
		if has_die_bonus:
			die_triggers = MaterialEffects.die_trigger_count(i, charm_ids, echo_slot, essence_ids, is_stress,
				EssenceEffects.extra_activations(i, order, essences, charm_ids, dice, hands_taken), order.size(), tail_slot,
				hands_taken == 0, participating.has(i))
			# Das Nachglühen addiert auf der SEITEN-Achse; die Essenz bleibt der
			# einzige Faktor der Würfel-Achse.
			face_triggers = MaterialEffects.face_trigger_count(dice[i], charm_ids, RuneEffects.extra_activations(rune_ids, charm_ids), essence_ids)
		# Manometer: wie oft die SEELE wirkt - Krit, Wachstum und Glieder, nie der
		# Würfel selbst (das bliebe ein zweiter Faktor auf der Würfel-Achse).
		var essence_repeat := EssenceEffects.essence_repeat_count(i, order, essences, charm_ids)
		# Röntgenlicht: die Gegenseite feuert JE Würfel-Trigger, direkt hinter dem
		# Zündungs-Batch dieses Antritts - wie ein garantierter Pointer, nur ohne
		# Chance und ohne Kette.
		var essence_links := essence_link_groups(ctx, i, die_triggers, essence_repeat,
			charm_ids, essence_ids, clause_growth)
		# LAUFENDER Wert: Knochen/Glas wandeln die obere Seite ZWISCHEN den
		# Zündungen, die zweite zählt also den gewachsenen Wert. Gewandelt wird
		# der PHYSISCHE Wert (raw), die Verwandlung liegt als Linse darüber - sonst
		# endete die Simulation woanders als apply_take_effects. Augen, die Material-
		# Rechnung DIESES Würfels und die BETRÄGE der würfelgebundenen Charms folgen
		# ihm; Trigger-Ordnung, Erkennung und jede ZIELWAHL bleiben an den liegenden
		# Werten.
		# Ein Durchgang mehr als Würfel-Trigger: der letzte trägt keine Zündung
		# mehr, nur die deterministischen Essenz-Glieder.
		for t in die_triggers + 1:
			for f in (face_triggers if t < die_triggers else 0):
				var shown := shown_value(running_values[i], charm_ids, essence_ids)
				# Augen erst durch die Charm-Linse, dann durch die Essenz (Antimaterie
				# kehrt um); das Photonengas legt das Licht jeder Zündung vor sich
				# obendrauf. Radon addiert hier NICHTS mehr - es schiebt die Augen
				# unten wirklich hinüber (spread_radon_once).
				base += EssenceEffects.eye_value_of(essence_ids, CharmEffects.eye_value(shown, charm_ids), charm_ids) \
					+ EssenceEffects.trigger_eye_bonus_of(essence_ids, triggers) \
					+ EssenceEffects.combo_level_base_of(essence_ids, combo_level) \
					+ EssenceEffects.discard_eye_bonus_of(essence_ids, discard_values, charm_ids) \
					+ EssenceEffects.firedamp_base_of(essence_ids, crits)
				triggers += 1
				if not has_die_bonus:
					continue
				base += MaterialEffects.base_bonus_once(i, materials, charm_ids, level, eye_sum)
				mult += float(MaterialEffects.mult_once_for(face_material, shown, charm_ids, level)) \
					+ float(EssenceEffects.mult_bonus_of(essence_ids)) \
					+ float(EssenceEffects.combo_level_mult_of(essence_ids, combo_level, charm_ids))
				# Der BETRAG folgt dem laufenden Wert (shown), das ZIEL bleibt an den
				# liegenden Werten - eine Zählung darf sich nie selbst umzielen.
				for j in charm_ids.size():
					base += CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, order, shown, materials)
					mult += float(CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, shown))
					mult += float(CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, scored, shown))
				base += CharmEffects.metronome_base(i, singles, charm_ids)
				mult += float(CharmEffects.strobe_mult(t * face_triggers + f, charm_ids))
				var cascade_add := CharmEffects.cascade_mult(shown, cascade_last, charm_ids)
				if cascade_add > 0:
					mult += float(cascade_add)
					cascade_last = shown
				# Material-Krit (Rubin III, Glas III), dann der Essenz-Krit - beide
				# in der Würfel-Substufe, VOR den würfelgebundenen Charm-Krits. Ozon
				# liest crits VOR seinem eigenen Schlag, zählt sich also nie selbst
				# mit; das Grubengas zündet an JEDEM Krit sofort mit.
				# Härteofen: der Krit einer veredelten Seite schlägt zweimal - je Schlag
				# ein eigener Krit, nie einer im Quadrat.
				var mat_crit := MaterialEffects.mult_crit_once_for(face_material, shown, charm_ids, level)
				for _r in MaterialEffects.payoff_repeats(level, charm_ids):
					if not is_equal_approx(mat_crit, 1.0):
						crits += 1
					mult *= mat_crit
				# Manometer: der Essenz-Krit schlägt mehrfach - je Schlag ein eigener,
				# nie einer im Quadrat (Härteofen-Grammatik). Ozon liest den Stand VOR
				# der Salve, der Tscherenkow dagegen je Schlag den frischen Energierest.
				var crits_before_essence := crits
				var spends_energy := EssenceEffects.spends_energy(essence_ids, charm_ids)
				for _e in essence_repeat:
					var ess_crit := EssenceEffects.crit_of(essence_ids, shown, crits_before_essence, ball_bonus,
						wild_eyes if i == wild else 0, charm_ids, energy,
						first_scoring_for(ctx, i), volcanic, t == 0 and f == 0)
					if spends_energy and energy > 0:
						energy -= 1
					if not is_equal_approx(ess_crit, 1.0):
						crits += 1
					mult *= ess_crit
				for j in charm_ids.size():
					var die_crit := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, shown)
					if not is_equal_approx(die_crit, 1.0):
						crits += 1
					mult *= die_crit
				running_values[i] = MaterialEffects.mutate_value_once(running_values[i], face_material, charm_ids, level, essence_ids, rune_ids, essence_repeat, clause_growth)
				# Ansteckung: der Miasma-Würfel gibt jetzt die Hälfte seiner Augen an
				# jeden anderen gewerteten Würfel ab - vor deren Zündung, also zählen
				# sie den Zuwachs schon mit. Nur die obere Seite steckt an, nie ein Glied.
				MaterialEffects.spread_miasma_once(running_values, i, scored, essence_ids, rune_ids, charm_ids)
				# Bestrahlung: das Radon schiebt bei JEDER Zündung Augen auf jeden
				# anderen gewerteten Würfel - dauerhaft, also auch in die Defs.
				MaterialEffects.spread_radon_once(running_values, i, scored, essence_ids, charm_ids, essence_repeat)
			# Glieder: je Würfel-Trigger erst der dafür gewürfelte Pointer, dann das
			# Essenz-Glied (Röntgenlicht); im letzten Durchgang die Runen-Glieder.
			# Jedes feuert EINMAL wie eine Zündung mit getauschter Seite (nie
			# retriggert) - noch an der Position dieses Würfels, weil Krits die
			# Reihenfolge werten. Glieder tragen ihren eingefrorenen Wert (eine Kette
			# meint fremde Seiten). RUNES feuern hier NICHT: eine Rune gehört der oben
			# liegenden Seite, ein Glied ist per Definition eine andere.
			var links_now: Array = []
			if t < die_triggers:
				links_now = pointer_fires_at(ctx, i, t) + essence_links_at(essence_links, t)
			else:
				links_now = repeated_det_links(ctx, i, essence_repeat, charm_ids, essence_ids, clause_growth)
			for link in links_now:
				var link_value := CharmEffects.transform_value(int(link["value"]), charm_ids)
				var link_material := String(link["material"])
				var link_level := int(link.get("level", 1))
				base += CharmEffects.eye_value(link_value, charm_ids)
				triggers += 1
				if not has_die_bonus:
					continue
				base += MaterialEffects.base_once_for(link_material, charm_ids, link_level, eye_sum)
				mult += float(MaterialEffects.mult_once_for(link_material, link_value, charm_ids, link_level))
				for j in charm_ids.size():
					base += CharmEffects.die_charm_base_at(j, i, key, dice, charm_ids, ctx, order, link_value, materials)
					mult += float(CharmEffects.die_charm_mult_at(j, i, dice, charm_ids, ctx, link_value))
					mult += float(CharmEffects.die_charm_target_mult_at(j, i, dice, charm_ids, scored, link_value))
				var link_cascade := CharmEffects.cascade_mult(link_value, cascade_last, charm_ids)
				if link_cascade > 0:
					mult += float(link_cascade)
					cascade_last = link_value
				var link_crit := MaterialEffects.mult_crit_once_for(link_material, link_value, charm_ids, link_level)
				for _r in MaterialEffects.payoff_repeats(link_level, charm_ids):
					if not is_equal_approx(link_crit, 1.0):
						crits += 1
					mult *= link_crit
				for j in charm_ids.size():
					var link_die_crit := CharmEffects.die_charm_crit_at(j, i, dice, charm_ids, participating, link_value)
					if not is_equal_approx(link_die_crit, 1.0):
						crits += 1
					mult *= link_die_crit
	for j in charm_ids.size():
		base += CharmEffects.charm_base_bonus_at(j, key, dice, participating, charm_ids, ctx)
		mult += float(CharmEffects.mult_bonus_at(j, key, charm_ids) \
			+ CharmEffects.charm_mult_bonus_at(j, key, dice, materials, charm_ids, ctx, participating, scored))
		var static_crit := CharmEffects.charm_crit_at(j, dice, charm_ids, ctx, participating, key, scored)
		if not is_equal_approx(static_crit, 1.0):
			crits += 1
		mult *= static_crit
	# Antimaterie zählt negativ - die Basis darf trotzdem nie unter null fallen.
	return [maxi(0, base), mult]

## Beste Hand des Wurfs: die RANGHÖCHSTE zutreffende Kategorie (HAND_PRIORITY von
## oben nach unten, erster Treffer gewinnt). Was physisch daliegt, zählt - Punkte
## vergleichen wir bewusst NICHT mehr über Kategorien hinweg, sonst nimmt das
## Spiel bei drei Zweierpäschen ein hochgestuftes Zwei-Paare. Gedrosselte
## Kategorien werden übersprungen (die Hand rutscht zur nächsten passenden).
static func best_hand(dice: Array[int], charm_ids: Array[String] = [], is_first_hand: bool = false, materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# Erkennung auf den verwandelten Werten, Wertung mit den ROHEN: score_category
	# verwandelt selbst und braucht die physischen Werte für den Wertwandel
	# (Knochen/Glas) - zweimal verwandelt käme dort die Linse als Seitenwert an.
	var shown := shown_values(dice, charm_ids, ctx)
	var best_key := ONE_KIND
	var best_score := 0  # bleibt 0, wenn keine Kategorie durchkommt (Drossel/Parität)
	for key in HAND_PRIORITY:
		if is_throttled(key, ctx) or not qualifies(key, shown, ctx, charm_ids):
			continue
		best_key = key
		best_score = score_category(key, dice, charm_ids, is_first_hand, materials, combo_levels, ctx)
		break
	return {
		"key": best_key,
		"label": label_for(best_key),
		"mult": _total_mult(best_key, dice, charm_ids, materials, combo_levels, ctx),
		"score": best_score,
	}

## Positionen in dice, die zur Kategorie gehören - nur diese zählen für den
## Basiswert, und nur auf ihnen wirken Seiten-Materialien. dice sind die ROHEN
## Werte: die Verwandlung UND die Essenz-Linse legt diese Funktion selbst auf.
## Immer SLOT-sortiert: Würfel triggern links nach rechts, nie in Gruppenfolge.
static func participating_indices(key: String, dice: Array[int], charm_ids: Array[String] = [], ctx: Dictionary = {}) -> Array[int]:
	dice = shown_values(dice, charm_ids, ctx)
	var legal := legal_indices(dice, ctx)
	var sub := dice if legal.size() == dice.size() else _legal_dice(dice, legal)
	# Joker auf die HÖCHSTE tragende Zahl setzen - deterministisch und in einer
	# Linie mit _best_value_with_count, das ebenfalls den höchsten Wert wählt.
	var wild := _wild_index_in(legal, ctx)
	if wild >= 0:
		sub = sub.duplicate()
		for value in range(6, 0, -1):
			sub[wild] = value
			if _qualifies_plain(key, sub, charm_ids):
				break
	var result: Array[int] = []
	if legal.size() == dice.size():
		# assign: die Zweige von _participating_unsorted liefern untypisierte Arrays.
		result.assign(_participating_unsorted(key, sub, charm_ids))
	else:
		# Auf der gefilterten Liste erkennen, dann die Indizes zurückrechnen.
		for k in _participating_unsorted(key, sub, charm_ids):
			result.append(legal[k])
	result.sort()
	return result

static func _participating_unsorted(key: String, dice: Array[int], charm_ids: Array[String] = []) -> Array[int]:
	match key:
		SIX_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 6), 6)
		FIVE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 5), 5)
		FOUR_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 4), 4)
		THREE_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 3), 3)
		TWO_PAIR:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		TWO_KIND:
			return _indices_for_value(dice, _best_value_with_count(dice, 2), 2)
		ONE_KIND:
			return [] if dice.is_empty() else [_index_of_highest(dice)]
		FOUR_KIND_AND_PAIR:
			var pair := _find_count_and_other_count(dice, 4, 2)
			return _indices_for_value(dice, pair[0], 4) + _indices_for_value(dice, pair[1], 2)
		FULL_HOUSE:
			var pair := _find_count_and_other_count(dice, 3, 2)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 2)
		DOUBLE_THREE_KIND:
			var pair := _find_two_groups_with_at_least(dice, 3)
			return _indices_for_value(dice, pair[0], 3) + _indices_for_value(dice, pair[1], 3)
		THREE_PAIRS:
			var result: Array[int] = []
			for value in _values_with_count_at_least(dice, 2):
				result.append_array(_indices_for_value(dice, value, 2))
			return result
		SMALL_STRAIGHT:
			return _indices_for_straight(dice, 5, charm_ids)
		LARGE_STRAIGHT:
			return _indices_for_straight(dice, 6, charm_ids)
	return []

## Farkle-Regel: sicher ist ein Neu-Würfeln nur, wenn die neue Hand im RANG
## (HAND_PRIORITY) strikt höher steht - Punkte entscheiden nie. Gleicher Rang
## farklet also auch mit mehr Augen, und ein Dreier- auf einen Viererpasch kann
## nie farkeln. Materialien und Übertaktungs-Stufen bleiben in der Signatur, weil
## sie zur Hand gehören; auf den Vergleich wirken sie nicht mehr. Die Drossel im
## ctx dagegen schon - sie entscheidet, WELCHE Kategorie best_hand liefert. ctx
## gilt für beide Seiten gleich - AUSSER die alte Seite bringt ihr eigenes old_ctx
## mit (Essenz-Glieder, Veredelungen und Essenzen hängen an den Würfeln VOR dem
## Neuwurf, wie old_materials).
static func is_strictly_better(new_dice: Array[int], old_dice: Array[int], charm_ids: Array[String] = [], new_materials: Array[String] = [], old_materials: Array[String] = [], combo_levels: Dictionary = {}, ctx: Dictionary = {}, old_ctx: Dictionary = {}) -> bool:
	var new_hand := best_hand(new_dice, charm_ids, false, new_materials, combo_levels, ctx)
	var old_hand := best_hand(old_dice, charm_ids, false, old_materials, combo_levels, ctx if old_ctx.is_empty() else old_ctx)
	# Eine Hand, die gar nichts wertet (Drossel/Parität), ist nie ein Fortschritt.
	if int(new_hand["score"]) <= 0:
		return false
	return hand_rank(String(new_hand["key"])) < hand_rank(String(old_hand["key"]))

## Rangplatz einer Kategorie in HAND_PRIORITY (kleiner = ranghöher); unbekannte
## Keys stehen hinter allem.
static func hand_rank(key: String) -> int:
	var index := HAND_PRIORITY.find(key)
	return index if index >= 0 else HAND_PRIORITY.size()

## Für die Kombinationsbildung zählt nur die LETZTE Ziffer (1, 11, 21 -> 1);
## der volle Wert zählt weiterhin für die Punkte.
static func _digit(value: int) -> int:
	return value % 10

static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		var d := _digit(value)
		result[d] = result.get(d, 0) + 1
	return result

static func _sum(dice: Array[int], charm_ids: Array[String] = []) -> int:
	var total := 0
	for value in dice:
		total += CharmEffects.eye_value(value, charm_ids)
	return total

## Kombinationsziffer einer Gruppe mit mindestens n Würfeln - die des Würfels
## mit dem höchsten echten Wert (punktträchtigste Gruppe gewinnt). -1 = keine.
static func _best_value_with_count(dice: Array[int], n: int) -> int:
	var counts := _counts(dice)
	var best_digit := -1
	var best_value := -1
	for i in dice.size():
		var d := _digit(dice[i])
		if counts.get(d, 0) >= n and dice[i] > best_value:
			best_value = dice[i]
			best_digit = d
	return best_digit

static func _has_count_at_least(dice: Array[int], n: int) -> bool:
	for count in _counts(dice).values():
		if count >= n:
			return true
	return false

static func _count_groups_with_at_least(dice: Array[int], n: int) -> int:
	var qualifying := 0
	for count in _counts(dice).values():
		if count >= n:
			qualifying += 1
	return qualifying

static func _has_two_groups_with_at_least(dice: Array[int], n: int) -> bool:
	return _count_groups_with_at_least(dice, n) >= 2

static func _has_count_and_other_count(dice: Array[int], n: int, other_n: int) -> bool:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return true
	return false

## Straßen laufen auf dem ZIFFERNRING 0-9: length aufeinanderfolgende Positionen,
## Start beliebig, Umlauf über die 0 erlaubt (8,9,10,21,22,23 -> 8,9,0,1,2,3 ist
## eine große Straße). 11-12-13-14-15 gilt weiter wie 1-2-3-4-5. Mit Zahnlücke
## genügen length Ziffern in einem Fenster von length+1 - genau ein Loch.
const DIGIT_RING := 10

static func _has_straight_of_length(dice: Array[int], length: int, charm_ids: Array[String] = []) -> bool:
	return not _straight_digits(dice, length, charm_ids).is_empty()

## Die Ziffern der ersten passenden Straße in Ringfolge ([] = keine).
static func _straight_digits(dice: Array[int], length: int, charm_ids: Array[String] = []) -> Array[int]:
	if length <= 0:
		return []
	var unique := {}
	for value in dice:
		unique[_digit(value)] = true
	# Erst lückenlos - ein volles Fenster gewinnt immer vor einem gelochten.
	var plain := _straight_window(unique, length, length)
	if not plain.is_empty() or not CharmEffects.straight_gap_allowed(charm_ids):
		return plain
	return _straight_window(unique, length, length + 1)

## Erstes Fenster aus span Ringpositionen, in dem mindestens length Ziffern
## liegen - geliefert werden genau diese Ziffern in Ringfolge.
static func _straight_window(unique: Dictionary, length: int, span: int) -> Array[int]:
	if span > DIGIT_RING:
		return []
	for start in DIGIT_RING:
		var found: Array[int] = []
		for step in span:
			var d := (start + step) % DIGIT_RING
			if unique.has(d):
				found.append(d)
		if found.size() >= length:
			return found.slice(0, length)
	return []

static func _index_of_highest(dice: Array[int]) -> int:
	var best_index := 0
	var best_value := -1
	for i in dice.size():
		if dice[i] > best_value:
			best_value = dice[i]
			best_index = i
	return best_index

## Erste n Indizes mit der Kombinationsziffer digit.
static func _indices_for_value(dice: Array[int], digit: int, n: int) -> Array[int]:
	var result: Array[int] = []
	for i in dice.size():
		if _digit(dice[i]) == digit:
			result.append(i)
			if result.size() >= n:
				break
	return result

## Wie _has_count_and_other_count, liefert aber [value, other_value].
static func _find_count_and_other_count(dice: Array[int], n: int, other_n: int) -> Array[int]:
	var counts := _counts(dice)
	for value in counts:
		if counts[value] < n:
			continue
		for other_value in counts:
			if other_value != value and counts[other_value] >= other_n:
				return [value, other_value]
	return [0, 0]

## Wie _has_two_groups_with_at_least, liefert aber die beiden Werte.
static func _find_two_groups_with_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
			if found.size() >= 2:
				break
	return found

static func _values_with_count_at_least(dice: Array[int], n: int) -> Array[int]:
	var counts := _counts(dice)
	var found: Array[int] = []
	for value in counts:
		if counts[value] >= n:
			found.append(value)
	return found

## Je ein Index pro Ziffer der ersten passenden Straße; Duplikate bleiben außen
## vor, ein Loch (Zahnlücke) wird schlicht übersprungen.
static func _indices_for_straight(dice: Array[int], length: int, charm_ids: Array[String] = []) -> Array[int]:
	var first_index_of := {}
	for i in dice.size():
		var d := _digit(dice[i])
		if not first_index_of.has(d):
			first_index_of[d] = i
	var result: Array[int] = []
	for d in _straight_digits(dice, length, charm_ids):
		result.append(int(first_index_of[d]))
	return result
