# Plan: Würfel-Pakete mit Größe, Güte und drei Glücks-Mechaniken (2026-11-12)

Spieler-Entscheid, Spec = Obsidian-Seite `E:/Obsidian Vault/Games/Fumble/46 Würfel-Pakete - Größe, Güte und das Öffnen.md` samt dem Abschnitt *Entschieden*. Gilt NUR für WÜRFEL-Pakete; Karten-Pakete (`CardPack`, Kassette, ihre Auswahl) bleiben unverändert — später.

Zwei Wellen, NACHEINANDER (nie zwei Godot-Prozesse zugleich): **Welle 1 = Regeln** (data/, core/, Laden-Texte, Unit-Tests), **Welle 2 = Bühne** (table/, ui/, scene_root, Integration). Welle 2 baut auf der Schnittstelle von Welle 1.

## Die Regeln (Welle 1)

Ein Würfel-Paket hat drei Felder: **Sorte** (wie bisher fünf), **Größe** (Klein/Normal/Groß/Riesig) und neu **Güte** (`QUALITY_STANDARD` 0 / `QUALITY_FINE` 1 „Edel“ / `QUALITY_ROYAL` 2 „Royal“). Größe und Güte würfeln im Laden UNABHÄNGIG.

Beim Öffnen laufen DREI Glücks-Mechaniken; jede hat eine UNTERGRENZE aus dem Paket und steigt mit `GameRun.effective_luck()`:

1. **Wie viele Würfel** — Grundzahl nach Größe **2 / 3 / 4 / 5**, dann die ZUGABE-KETTE: erster Zusatz-Würfel mit 20 % + 1,5 Punkte je Glück (Deckel 65 %), jeder weitere mit der vorigen Chance × 0,6, höchstens 5 Zusätze, nie mehr als 10 Würfel.
2. **Wie gut jeder Würfel ist** — JEDER Würfel einzeln: Untergrenze ist die Güte des Pakets; Aufstieg um eine Stufe mit 10 % + 1 Punkt je Glück (Deckel 50 %), ein zweiter Aufstieg mit der halben Chance; nie über Royal.
3. **Wie viele Wahlen** — Grundzahl nach Größe **1 / 1 / 2 / 2**, dann eine Kette: erste Zusatz-Wahl mit 20 % + 1 Punkt je Glück (Deckel 60 %), jede weitere mit der halben Chance. **HARTE Regel: Wahlen ≤ Würfelzahl − 1** (und ≥ 1). Der alte Hauptgewinn „alle nehmen“ entfällt für Würfel-Pakete; die Klausel *Freie Hand* gibt hier das Maximum (Würfelzahl − 1), *Zugabe* +1 innerhalb des Deckels.

Was die Güte eines WÜRFELS bewirkt (in `DiceOffer.roll_pack_die`, neuer Parameter `quality`):

| Güte | Augen | Seele | Material / Runen |
| --- | --- | --- | --- |
| Standard | wie heute | wie heute (`pack_soul_chance`) | wie heute |
| Edel | Würfel-Rahmen eine Fortschrittsstufe höher | Chance +20 Punkte, seltene Seelen doppelt so oft | Material-Chance 55 %, Veredelung doppelt so oft |
| Royal | zwei Stufen höher | Chance +40 Punkte, Seltenheit eine Stufe gehoben | Material-Chance 75 %, mindestens eine veredelte Material-Seite, eine Rune sicher |

Die Sorten-Regeln (Seelen-Paket: immer Seele; Material-Paket: ≥ 2 Material-Seiten) gelten weiter und stapeln mit der Güte.

Weitere Regeln:
- **Gebucht wird beim Kauf** (Buchung vor dem Licht): Würfel, ihre Güten und die Wahlen stehen in der `PackChoice` fest. Neu je Option die Güte (`PackChoice.qualities: Array[int]`, parallel zu `options`) und die Grundzahlen zum Anzeigen (`base_count`, `base_picks`).
- **Neu mischen** (1 ⚡, einmal je Paket; Charm *Neu gemischt* einmal je Runde gratis) würfelt ALLES neu: Zahl, Würfel, Güten, Wahlen.
- **Beigabe / Beipack** heben die Grundzahl der Würfel um 1, **Verplombt** senkt sie um 1 (nie unter 2); **Glücksgriff** verdoppelt die Chancen der Zugabe-Kette UND der Wahl-Kette (Deckel bleiben).
- **Preise**: feste Tabelle Sorte × Größe (Formel: erwartete Wahlen bei Glück 0 × durchschnittlicher Würfelwert der Sorte × 1,15, gerundet; ein Test prüft ±2) mal Güte-Faktor **1,0 / 1,7 / 2,8**, gerundet.
- **Laden**: Güte-Gewichte Standard 65 / Edel 27 / Royal 8, je `shop_tier()` über 1 wandern +3 auf Edel und +2 auf Royal (von Standard). Klausel-Haken für später vorsehen, aber KEINE neuen Charms/Klauseln in dieser Welle.
- **Auskunft im Laden** (`DicePack.info_body`, Name): nennt Sorte, „Mindestens N Würfel“, „Mindestens K Wahlen“ und die Güte — NIE Chancen (bleiben verborgen) und nie die genaue Zahl. Name z. B. „Großes Kraft-Paket · Edel“.
- **Nebenwetten** (`SideBet`, `DICE_PACK`): das teuerste bezahlbare Paar aus Größe und Güte der gewürfelten Sorte.
- `CardPack` und seine Tabellen bleiben für Karten-Pakete unberührt; was Würfel-Pakete bisher von dort liehen (`OPTION_COUNTS`, `roll_picks`, `choice_line`), bekommt in `DicePack` eigene Regeln.

**Schnittstelle für Welle 2** (Namen dürfen abweichen, aber dann im Bericht nennen): `DicePack.quality`, `DicePack.base_count(size)`, `DicePack.base_picks(size)`, `DicePack.QUALITY_NAMES`, `DicePack.make(sort, size, quality)`; `PackChoice.qualities`, `PackChoice.base_count`, `PackChoice.base_picks`, `PackChoice.picks`; `GameRun.reshuffle_pack_choice` würfelt alles neu.

Tests (Unit): die drei Ketten samt Deckeln und Glück (mit festem RNG), Wahlen ≤ Zahl − 1 in jedem Fall, Güte je Würfel ≥ Paket-Güte, Güte-Wirkung auf Augen/Seele/Material, Preise gegen Formel und Faktor, Laden-Gewichte je Stufe, Neu mischen würfelt Zahl und Wahlen neu, Beigabe/Verplombt/Glücksgriff/Freie Hand/Zugabe, Nebenwetten-Paar. Doku: `scripts/data/CLAUDE.md`, `scripts/core/CLAUDE.md`, kurz.

## Die Bühne (Welle 2)

**Am Paket** (`CardPackView`, Würfel-Schatulle): Naht = Sorte (wie heute); Augen auf dem Deckel = GRUNDZAHL der Würfel (2–5); Metall von Schließe und Augen = GÜTE: Stahl / Gold / Royal (dunkles Chrom mit violettem Schimmer, die Naht pulst leise). Gold hängt nicht mehr an der Größe „Riesig“. Überall, wo eine Schatulle gebaut wird (Laden-Bucht, Wett-Tresen, Auszahlungs-Ablage, Auswahl), reist die Güte mit.

**Das Öffnen** (ersetzt die Aufstellungs-Show; `CaseShow` bleibt Baukasten für Töne, Strahl, Ringe):

1. Anflug an den oberen Grubenrand, Deckel springt auf — wie heute. Die Kamera rahmt die ganze Grube.
2. **AUSWURF mit echter Physik**: die Würfel werden EINZELN aus der Schatulle in die Grube geschossen — Wegwerf-Körper mit der Physik der Wurfgrube (prallen von den Kraftfeld-Wänden und voneinander ab), das Ergebnis der Lage zählt nicht. Sie sind NICHT die Körper des Rundenwurfs und rühren `DiceController`/Rundenzustand nicht an. Kein Netz, kein Platz, kein Zähler in dieser Phase — der Spieler soll die Zahl nicht vorher kennen.
3. Die GRUND-Würfel kommen im ruhigen Takt. Danach RÜTTELT die Schatulle (Licht und Ton bauen sich auf) — und dann schlägt entweder der Deckel zu, oder es schießt noch einer heraus, größer als der vorige (heller, höher, Wand-Blitz), und sie rüttelt erneut. Das Rütteln vor dem Zuschlagen gibt es IMMER.
4. Deckel zu → alle Würfel kommen zur Ruhe (Deckel: nach einer Höchstzeit hart einfrieren) → sie heben sich ZUGLEICH und gleiten in die AUFSTELLUNG (bis zwei Reihen zu fünf, Plätze meldet `PackChoiceView`).
5. **GÜTE-ENTHÜLLUNG, Würfel für Würfel**: über/an jedem Platz läuft eine kurze Stufen-Anzeige (Standard → Edel → Royal, Farben weiß / gold / violett) und rastet auf der Güte dieses Würfels ein; ein Aufstieg über die Paket-Güte bekommt seinen eigenen Moment. Mit dem Einrasten geht das NETZ (`DieNetView`) dieses Würfels auf, und sein Platz behält den Saum in der Güte-Farbe.
6. **Die WAHLEN als Casino-Moment**: eine RISIKOLEITER (Lampen 1 … Würfelzahl − 1; die Grundzahl leuchtet fest, das Licht springt darüber auf und ab, wird langsamer und bleibt auf der gebuchten Zahl stehen), mit Ton je Sprung und einem Schlag beim Halt. Danach „Wähle K von N“.
7. Wählen, Nehmen wie heute. **Neu mischen**: alle Würfel springen zurück in die Schatulle, Deckel zu, und die GANZE Öffnung (Schritte 2–6) läuft neu mit den neu gebuchten Werten.
8. Bestätigen wie heute: Gewählte fliegen zur Schale, der Rest zurück in die Schatulle, der Tisch zieht sie ein (`PIT_CASE`), dann der Zwang.

Ein Klick überspringt jeweils bis zum Ende der laufenden Phase bzw. bis zur Wahl (Endzustand zuerst). `_settle_pack_openings` bleibt der EINE harte Aufräum-Pfad und räumt auch Physik-Körper, Leiter und Enthüllung.

Laden-Block der Würfel-Pakete: Name, Preis und die neue Auskunft aus `DicePack.info_body`.

Tests: `PackChoiceView` (Aufstellung bis 10, Güte-Saum je Platz, Netz erst nach Enthüllung, Leiter mit N − 1 Lampen und Halt auf der gebuchten Zahl — als reine Funktion/Signale prüfbar), `CardPackView` (Augen = Grundzahl 2–5, Metall = Güte), `CaseShow`-Stufen. scene_root-Abläufe per Probe (auch Abbruch in jeder Phase) und Boot. Doku: Wurzel-`CLAUDE.md` (*Die PAKET-AUSWAHL*, *EINE Größe je Ding* falls berührt), `scripts/table/CLAUDE.md`, `scripts/ui/CLAUDE.md`.
