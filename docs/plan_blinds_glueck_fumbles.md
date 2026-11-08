# Welle: Blinds, Glück, Fumbles (Spieler-Entscheid 2026-11-07)

Die drei Vertragskarten je Runde bleiben. Neu: der Blind wächst prozentual und
DAUERHAFT durch Verträge, GLÜCK ersetzt die rundengerechnete Fortschrittsstufe,
und Fumbles werden ein Laufzähler mit eigenem Inhalt. UI-Wörter: **Blind** (der
Blind), **Glück**, **Fumbles**; Code behält `quota`/`stress`.

## A. Die Blind-Kurve (core/game_run.gd)

- Neuer Laufzustand `blind_value: float` (exakt, ungerundet), Start `BASE_GOAL` 150.
- **Natürliches Wachstum** beim Eintritt in Runde n (n ≥ 2):
  `blind_value *= 1 + blind_growth(n)`, `blind_growth(n) = 0.10 + 0.05 * block_of_round(n)`
  → R2–R6 je +10 %, R7–R12 je +15 %, R13–R18 je +20 %, dann 25 % … (Block = 6 Runden,
  die Boss-Runde bleibt Runde 6, 12, …).
- **Gerundet wird nur das Ziel**: `round_goal = floor_to_25(blind_value)`, mindestens 25
  (`BLIND_ROUNDING` 5, seit 2026-11-08; vorher 25). 663 → 660. Der Akkumulator bleibt exakt.
- `goal_for_round`/`GOAL_INCREMENT` (75er-Treppe) sterben bzw. werden zur Projektion:
  `projected_blind(k)` = blind_value × Wachstum der Runden round_number+1..k, gerundet.
- **Verträge heben den Blind DAUERHAFT** — die Blind-Malusse werden `Scope.INSTANT` und
  multiplizieren `blind_value` beim Unterschreiben. Sie gelten SOFORT (die Runde, für die
  unterschrieben wird, ist noch nicht geworfen) und für jede spätere Runde:
  - Blind-Aufschlag (T1) **+10 %**, Blind-Aufschlag II (T2) **+20 %**,
    Blind-Schock (T3) **+35 %**, Wucherklausel (T3) **+50 %**.
  - Eichung (T2-Bonus) wird **dauerhaft −10 %** (der Winkeladvokat wendet sie zweimal an).
  - Hohe Erwartungen (Boss) BLEIBT rundenweise (+500 % nur in dieser Runde).
  - Kartentexte: „Blinds dauerhaft +10 %“ usw., `text_for` samt Winkeladvokat-Fassung.
  - Der Zweiter-Quota-Malus-Wächter (`_quota_blocked`) betrifft nur noch die Boss-Klausel;
    dauerhafte Hebungen dürfen sich über Runden stapeln (das ist der Sinn).
- `effective_goal()` = `round_goal` × rundenweise Faktoren (Hohe Erwartungen, Galgenfrist).
  Überladungs-Stufen, Wetten (`SideBet.roll_offers(..., round_goal)`) und Sieg-Prüfung
  hängen wie bisher daran.
- **Fahrplan**: vergangene Stationen zeigen den WIRKLICH gespielten Blind (Historie je
  Runde merken), die laufende den aktuellen, künftige die Projektion. Unterschreiben
  hebt die laufende und alle künftigen Stationen sichtbar an.

## B. GLÜCK (core + HUD)

- Neuer Laufzustand `luck: int`, Start 0. **+1 je geschaffter Runde** (in `advance_round`,
  das nur nach einer geschafften Runde läuft — prüfen).
- `progress_tier()` = `clampi(1 + luck / LUCK_PER_TIER, 1, TIER_MAX)`, `LUCK_PER_TIER` 3.
  Ohne Glücks-Verträge ist das byteweise die heutige Leiter (1 + (Runde−1)/3). Alles,
  was heute an `progress_tier()` hängt (Laden-Seltenheit, Multiplikator-Chance,
  Sonderposten, Wett-Stufe, Würfel-Angebote, Automaten-Preise, Hub-Medaillon), folgt damit
  dem Glück. Doku „gerechnet, kein Zustand“ entsprechend korrigieren.
- **Glücks-Klauseln** (neues Tag `TAG_LUCK`, eigene Farbe; `Scope.INSTANT`):
  - Bonus T1 „Glückspfennig“: Glück +1 · T2 „Glückssträhne“: Glück +2 · T3 „Glückskind“: Glück +3
    (Winkeladvokat verdoppelt, ausgeschriebene Fassung in `text_for`).
  - Malus T2 „Unglückszahl“: Glück −2 (nie unter 0).

## C. FUMBLES als Laufzähler

- `farkle_count += 1` zieht aus `scene_root` in `GameRun.note_fumble()` (Buchung im Kern).
  Gezählt werden wie heute nur ECHTE Fumbles (verziehene nicht). Der Zähler sinkt nie.
- Dazu `block_fumbles` (Fumbles im laufenden Block, Reset beim Blockwechsel).
- **Fumble-Automaten**: Joker-Gewicht `W_JOKER` + 0,05 je Lauf-Fumble, höchstens +1,0
  (also bis 2,0). Der Zähler kommt als Parameter in den Wurf, `SlotMachine` bleibt ohne `GameRun`.

## D. Neuer Fumble-Inhalt

Modelle: Charms ohne `.glb` fallen auf `CharmRowView.placeholder_model`, Module ohne
`part_<id>.glb` auf das Grundgehäuse — keine Assets in dieser Welle.

**Charms** (`Charm`-Konstante, Katalog, Seltenheit, Preis, Wirkung in `CharmEffects`):
- **Pechvogel** (statisch): +1 Mult je 2 Fumbles des Laufs.
- **Fumble-Rente** (Geld, Rundenende): +$1 je 3 Fumbles des Laufs; eigene Zeile auf der
  Auszahlungs-Seite (Charm-Name, wie die anderen Geld-Charms).
- **Galgenfrist**: jeder echte Fumble senkt den Blind DIESER Runde um 3 % (multiplikativ,
  rundenweise, `blind_value` bleibt unberührt; der Balken zieht mit).
- **Schwarze Katze**: Ladenpreise −2 % je Fumble des Laufs, höchstens −30 %.

**Essenzen** (`Essence`, Wirkung in `EssenceEffects`/Fumble-Pfad):
- **Narbe**: nimmt der Würfel an einem echten Fumble teil, wächst seine obere Seite
  dauerhaft um +1 Auge.
- **Kühlmantel**: ein echter Fumble kühlt diesen Würfel um 1 Ladung statt ihn zu heizen.

**Module** (`ComboPart`, Wirkung in `ComboPartEffects`):
- **Fehlerspeicher** (`PHASE_COMBO`): +Mult = Fumbles dieses Blocks.
- **Nachbrenner** (`PHASE_CRIT`): die erste Hand dieser Kombination nach einem Fumble ×2.

**Klauseln**:
- **Pechsträhne** (Malus T2, `Scope.ROUND`): jeder echte Fumble dieser Runde hebt die
  Blinds DAUERHAFT um 2 % (`blind_value`, wirkt sofort auf die laufende Runde).
- **Strafgebühr** (Boss-Kondition): jeder echte Fumble kostet $5 (nie unter $0).

## E. HUD: die Lauf-Werte am Hub

Neben dem Fahrplan am Hub drei Anzeigen (ui/table-Grammatik, MELDEN statt anfassen):
**„Nächster Blind 300“** (= `projected_blind(round_number + 1)`), **„Glück 4“**,
**„Fumbles 7“**. Je Anzeige ein Hover über die bestehende `HintCard`:
- Blind: „Wächst je Runde um 10 % (dieser Block); Verträge heben ihn dauerhaft.“
- Glück: aktuelle Stufe und ab welchem Glück die nächste kommt, plus was sie hebt.
- Fumbles: welche Besitztümer den Zähler gerade lesen (z. B. „Pechvogel: +3 Mult“).
Ändert sich ein Wert, tickt die Zahl hoch und blitzt kurz auf (kein neuer Komet).
Lexikon: Eintrag **Glück** neu, **Blind**, **Vertrag** und **Fumble** auf die neuen Regeln.

## F. Pflicht

- Schichtenregel, kurze deutsche Kommentare, „Buchung vor dem Licht“.
- Bestehende Tests an die neue Kurve anpassen (viele rechnen mit 150/225/…); neue
  Unit-Tests für Kurve, Rundung, dauerhafte Hebung, Glück→Stufe, jeden neuen Inhalt.
- Doku: Wurzel-CLAUDE.md (Kurzform), `scripts/core/CLAUDE.md` (Abschnitt Blind/Verträge,
  Fortschrittsstufe), `scripts/data/CLAUDE.md` wo nötig.
