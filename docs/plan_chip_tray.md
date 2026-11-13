# Das CHIP-TRAY — Plan (Spieler-Entscheide 2026-11-12)

Ersetzt den Schatz-Screen (`TreasureChestView` + Turm-Rack aus `ChipStackView`) durch ein
geneigtes Chip-Tray: EINE Rinne je Stückelung, die Chips liegen FLACH auf dem schrägen
Rinnenboden, die RECHTE Seite des Trays ist im Tisch versunken. Getauscht wird von selbst:
was eine Rinne voll macht, rutscht der Schwerkraft nach rechts in den Tisch, und in der
nächsthöheren Rinne kommt ein Chip aus dem Tisch.

## Entscheide

1. Chips liegen **flach**, mit dem Rinnenboden leicht nach rechts geneigt.
2. Tausch **automatisch**.
3. Ladenkauf zahlt **vorerst weiter als Licht** (der Wurf-Umzug bleibt eine spätere Welle).
4. Stückelungen bis **10.000**, so viele Stufen, daß das Tray **genau so groß ist wie der
   Wett-Tresen links daneben** (Breite UND Höhe).

## Maße (gemessen 1280 × 720, 2026-11-12)

- Wett-Tresen: **388,4 × 570,0 Display-px = 10,36 (Welt-Z) × 15,20 (Welt-X)**.
- Tray: dasselbe Rechteck, direkt rechts daneben (Fuge wie heute `size.x * 0.005`).
  Der heutige Schatz ist doppelt so breit (20,72) — die frei werdende Hälfte bleibt frei.
- Chip unverändert (`CHIP_RADIUS` 0,9, `CHIP_HEIGHT` 0,28 — EINE Größe je Ding; die
  Gewinn-Stapel der Wetten und die Wurf-Körper behalten sie).
- Innenhöhe ≈ 15,2 − 2 × Rahmen (≈ 0,3) = 14,6 → **7 Rinnen** zu je ≈ 2,09 Teilung
  (1,8 Chip + ≈ 0,29 Steg). Eine achte paßt nicht.
- Innenbreite ≈ 9,76 → **5 flache Chips** nebeneinander (9,0). Mehr braucht keine Rinne:
  im Ruhezustand liegen höchstens Verhältnis − 1 = 4, der fünfte löst den Tausch aus.

## Die Leiter: 7 Stufen

| Rinne | Wert | Verhältnis zur nächsten | Ruhe-Maximum | Farbe (Vorschlag) |
|---|---|---|---|---|
| 1 | 1 | 5 | 4 | Neon-Blau (bleibt) |
| 2 | 5 | 5 | 4 | Neon-Rot (bleibt) |
| 3 | 25 | 4 | 3 | Neon-Grün (bleibt) |
| 4 | 100 | 5 | 4 | Schwarz-Gold (bleibt) |
| 5 | 500 | 5 | 4 | Violett (neu) |
| 6 | 2.500 | 4 | 3 | Orange (neu) |
| 7 | 10.000 | — | unbegrenzt | Platin/Perlmutt (neu) |

- Ziffern ab 1.000 als „2,5K“ / „10K“ (der Kopf muß aufs Inlay passen).
- Die Rinne der 1er liegt UNTEN (zum Betrachter, dort passiert am meisten), 10.000 oben.
- **Überlauf der 10.000er**: ab dem sechsten Chip liegt eine zweite Lage darauf, und eine
  „×n“-Marke am Rinnenkopf nennt die Zahl. Es geht um ≥ 60.000 — ein seltener Fall, er muß
  nur sauber stehen.

## Die Kernregel: die Börse IST eine Funktion des Geldes

Mit automatischem Tausch ist jede Rinne immer unter ihrem Verhältnis, also ist die Belegung
**eindeutig** = `split_greedy(GameRun.money)` über die neue Leiter. Das Tray ist ein
ABAKUS. Folgen:

- Es gibt keinen eigenen Wallet-Zustand mehr, der driften könnte. `_wallet`, `seed_wallet`,
  `add_chips`/`remove_chips`, `payment_plan`, `GAIN_CAPS`/`split_gain` (für die Börse),
  `consolidate`, `exchange_values` und die Drift-Sicherung in `scene_root` sterben für den
  Schatz. (`split_gain` lebt weiter, wo die Kometen-Pakete gestückelt werden — prüfen, ob
  es dort auf die neue Leiter umzieht; `TableScreen` Z. 2076 spiegelt es.)
- Jede Geldänderung ist ein **Übergang alt → neu** zweier eindeutiger Belegungen. Die
  Zeremonie rechnet ihn als Folge von Schritten (rein statisch, unit-testbar):
  - **Einlauf** k Chips in Rinne r (Gewinn),
  - **Abgang** k Chips aus Rinne r (Zahlung),
  - **Übertrag** (Rinne r erreicht ihr Verhältnis → alle rutschen in den Tisch, Rinne r+1
    bekommt einen Chip aus dem Tisch — kann kaskadieren),
  - **Borgen** (eine Zahlung braucht mehr kleine Chips als da sind → EIN Chip der
    nächsthöheren belegten Rinne rutscht in den Tisch, und die kleineren Rinnen bekommen
    ihre Chips aus dem Tisch — Wechselgeld, rückwärts gelesen).
- Endzustand zuerst: die Belegung steht sofort; die Zeremonie fährt nur den Weg dorthin,
  und ein Abbruch setzt jeden Chip hart auf den Platz, den die Belegung ihm gibt.

## Die Bewegung: EINE Richtung

**Alles kommt LINKS herein, alles geht RECHTS hinaus.**

- Ein Chip ERSCHEINT am linken, oberen Ende seiner Rinne — als Ankunft eines Geld-Kometen
  oder „aus dem Tisch“ (Übertrag, Borgen) — und rutscht hinunter, bis er an die Reihe stößt.
- Am rechten Ende steht eine SPERRE an der Wand. Davor liegt die Reihe, die rechteste
  Kante an der Sperre.
- Beim Übertrag und beim Zahlen fällt die Sperre, die betroffenen Chips rutschen als ZUG
  durch einen Schlitz der rechten Wand unter die Anzeige, die Sperre steht wieder.
- Zahlung bleibt LICHT (Entscheid 3): der Komet zum Hub startet am rechten Rand des Trays,
  sobald der Chip im Tisch verschwunden ist (Rand blitzt in Chipfarbe).
- Einlauf aus dem Tisch: ein kleiner Hub (Lift, ein Chip groß) am linken Ende — die
  Hebebühnen-Grammatik, nur in klein. Ein Komet landet am selben Punkt und schlägt dort
  den Chip heraus.

### Physik: gefühlt, nicht Jolt

Flache Chips auf 6° RUTSCHEN (sie rollen nicht). Gerechnet wird eindimensional entlang der
Rinne: Beschleunigung `g · sin(α)` minus Reibung, ein kurzer Prall mit kleinem Rückstoß
beim Aufschlag an die Reihe, und ein leichter Stoß, der durch die Reihe läuft (die Reihe
ruckt um wenige Hundertstel). Deterministisch, ein Schreiber je Chip, hart abbrechbar,
testbar. Echte Rigid Bodies brächten hier nichts außer Unruhe: was in den Tisch rutscht,
ist ohnehin gleich verdeckt.

## Bauform

- **Eine permanente Grube** im Display (wie Magazin-Grube und Turm-Bucht): neuer Platz
  `TableScreen.PIT_TRAY`, in `PERMANENT_PITS`; `MAX_PITS` 32 → 33 in `table_screen.gd`,
  `screen_glass.gdshader` UND `table_ground.gdshader` im Gleichschritt.
- Darin die 3D-Einsätze: 7 Rinnenböden, um α ≈ 6° um Welt-X gekippt (rechts tiefer, Welt
  +Z = Bild-rechts), Stege dazwischen, Sperre und Wandschlitz je Rinne rechts, Lift links.
  Linkes Ende: Chip-Oberkante bündig mit der Fläche; rechtes Ende ≈ 1,0 tiefer.
  Wände und Boden in der Grubenhaut (`PackPitView.tune_lining` / `PIT_SKIN`) — eine
  Vertiefung liest wie die nächste.
- Hinter dem rechten Wandschlitz ein geschlossener Kasten unter der Anzeige (die
  Wandtaschen-Grammatik des Regalstapels), damit der Blick durch den Schlitz auf etwas
  fällt statt ins Nichts.

## Code

- **Neu `table/chip_tray_view.gd` (`ChipTrayView`)**: Leiter (`VALUES`, Farben, Verhältnisse),
  `belegung(money)`, `transition(old, new)` → Schrittliste (statisch), Rinnen-Geometrie
  (`groove_point(rank, i)`, `entry_point(rank)`, `exit_point(rank)`), feste Chip-Körper je
  Platz, der EINE Schreiber `seat_hard(belegung)`, die Rutsch-Simulation, `settle_hard()`.
- **`ChipStackView` bleibt** für die Gewinn-Stapel (`BetPrizeView`: `pile_span`,
  `pile_tower_count`, `pile_columns`) und die Wurf-Körper (`build_ghost_tower`), bekommt
  aber die neue Leiter samt neuen Farben (EINE Farbquelle). Rack, Schlitze, `mint_chip`,
  `towers`/`tower_at` und die Börse fallen weg.
- **`TreasureChestView`** wird zur FASSUNG des Trays: zeichnet Rahmen und Rinnen-Kopf (Wert,
  bei 10.000 die ×n-Marke), meldet das Grubenrechteck und die Rinnen in Display-Pixeln.
  `glint`, `flash_*_slot` werden zu Einlauf-/Auslauf-Blitzen je Rinne.
- **`scene_root`**: Platzierung (Z. ~1203–1239: Breite = Tresenbreite, Klickzone,
  Kamera-Ziel, Spill-Licht neu messen), `_on_money_changed` → Übergang abspielen,
  `_animate_money_gain/_spend/_change_out` fallen in EINE Übergangs-Zeremonie,
  Kometen-Ziele/-Starts auf Einlauf/Auslauf der Rinne, `_treasure_throw_point` → Abflug am
  Einlauf der Rinne des geworfenen Werts, `_bet_stake_chips` = `split_greedy(stake)`.
  **Gestorben**: die ganze Umtausch-Geste (`_try_start_chip_drag`,
  `_handle_chip_drag_input`, `_finish_chip_drag`, `_run_chip_exchange`, `chip_drag_*`,
  `_exchange_*`). Laufwechsel/Spielstand: `seat_hard(belegung(money))`.
- Die zehn Stellen, die Kometen-Pakete per `split_gain` stückeln (Charm-Geld, Take-Geld,
  Frankiermaschine …), bekommen die neue Leiter; die Buchung beim Einschlag bleibt, wo sie
  ist (Buchung vor dem Licht / benannte Einschlag-Zeremonien).

## Tests

- Unit (`test_chip_stack.gd` umbauen + neu `test_chip_tray.gd`): Belegung ist kanonisch,
  Übertrag kaskadiert (4·1 + 4·5 + 3·25 + 1 → 100), Borgen über mehrere Stufen
  (10.000 − 10), Überlauf der 10.000er, die Schrittliste endet immer exakt auf der neuen
  Belegung, der harte Abbruch mitten in jedem Schritt steht auf der Belegung.
- Integration: das Tray-Rechteck ist byte-gleich dem Tresen-Rechteck (Größe und Oberkante),
  kein Chip ragt über die Fläche, alle Körper links der Sperre im sichtbaren Teil.
- `test_bet_prize_view.gd`, `test_hub_tier_feature.gd`, `test_material_effects.gd` auf die
  neue Leiter prüfen.

## Lauf-Regeln für die Welle

`-gselect` auf das eine Skript während der Arbeit, die volle Suite EINMAL am Schluß,
jeder Godot-Lauf mit `--quit-after` im Vordergrund mit Bash-`timeout`, nie
`run_in_background`; nach `scene_root`-Änderungen einmal headless booten; `--import` nur
einmal nach dem Anlegen von `ChipTrayView`. Log mit `grep -c "Ignoring\|Parse Error"`
prüfen, bevor eine Pass-Zahl genannt wird. Doku-Abschnitt in `scripts/table/CLAUDE.md`
und Kurzform in der Wurzel-CLAUDE.md nachziehen.

## Umsetzung (2026-11-12) — Abweichungen vom Plan

- **Kopfspalte statt reinem Rahmen**: die Fassung trägt links eine Kopfspalte (7,5 % der
  Breite) mit Wert-Ziffern und der Kometen-SCHIENE; ein Komet im Loch wäre unsichtbar (das
  Glas verwirft die Anzeige dort), also landet er an der Schiene neben dem Einlauf. Die
  Innenbreite sinkt damit auf ≈ 9,43 statt 9,76 — fünf Chips passen weiter (der fünfte liegt
  0,01 vor dem Einlauf, ein Test hält es).
- **Zweite Lage der 10.000er endet einen Platz vor dem Einlauf** (`TOP_SHOWN` 9 statt 10):
  am linken Ende ragte ein Chip der zweiten Lage sonst 0,07 über die Fläche.
- **EIN durchgehender Wandschlitz** der rechten Grubenwand (`PackPitView.slot_walls`) statt
  eines Schlitzes je Rinne; die Stege laufen in den Kasten dahinter weiter.
- **Gutschrift-Kometen je Einlauf**: ein unterdrückungsfreier Gewinn schickt je Einlauf-Chip
  (`split_greedy` des Betrags, je Schritt höchstens `COMET_CAP` 5) einen Kometen an den
  Kopf seiner Rinne; der Einlauf wartet auf `land(rank)`. `split_gain` (bodenschwer, 100er
  und 25er gedeckelt) bleibt für die Kometen-PAKETE, die bei Ankunft buchen — die laufen
  dann ohne eigenen Kometen ein.
- **Unterdrückte Zahlung setzt hart**: der geworfene Wett-Einsatz ist das Bild, ein zweiter
  Abgang rechts zeigte das Geld doppelt.
- **Zahlung räumt erst, was liegt, dann wird geborgt** (Abgang, Borgen, Abgang): so trägt
  auch beim Borgen keine Rinne mehr als fünf Chips.
- **`TreasureChestView` behält seinen Namen** (die Klasse ist die Fassung); `glint` bleibt,
  `flash_entry`/`flash_exit` ersetzen die Schlitz-Blitze.
