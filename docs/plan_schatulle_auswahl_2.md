# Plan: Die Schatulle, zweite Fassung (2026-11-11)

Ersetzt den Ablauf von `docs/plan_schatulle_auswahl.md` (die erste Fassung ist gebaut, aber NICHT committet). Gilt nur für WÜRFEL-Pakete; Karten-Pakete bleiben unverändert.

## Was dem Spieler an der ersten Fassung nicht gefällt

1. Die Kamera ist beim Öffnen viel zu nah.
2. Man sieht die NETZE (Die-Views, `DieNetView`) der wählbaren Würfel nicht — die sind unverzichtbar. Am liebsten alle Netze aller wählbaren Würfel zugleich.
3. Die Schatulle ist zu klein: Charms und Klauseln können die Optionen auf bis zu ~10 Würfel heben.

## Der neue Ablauf

1. **Kauf** wie gehabt: die Schatulle fliegt als Körper (Trage-Bogen) aus der Laden-Bucht — aber an den OBEREN RAND der Wurfgrube (Bild-oben), nicht in ihre Mitte. Die Kamera rahmt die GANZE Grube (wie die bisherige Karten-Auswahl, `PACK_CHOICE_MARGIN`), nicht eng auf die Schatulle.
2. **Großes Öffnen**: der Deckel springt mit einer großen Geste auf (Überschwingen, Licht strömt aus dem Inneren — vorhandene Mittel: Emission, `TableScreen.pit_impulse`, Blitze, `DicePit.slam`, die Grubenwellen).
3. **Einer nach dem anderen springen die Würfel HERAUS**: jeder fliegt aus der Schatulle in die Grube und landet auf seinem Platz in einer AUFSTELLUNG (die Würfel liegen in der Grube, nicht mehr in der Schatulle). Die Plätze meldet `PackChoiceView` in Display-Pixeln (ui/ faßt nie Körper an); bis ~10 Würfel müssen Platz haben (zwei Reihen o. ä.), Würfel in `DiceTrayView.DIE_SCALE` (*EINE Größe je Ding*).
4. **Die NETZE**: unter jedem gelandeten Würfel steht sein `DieNetView`-Netz, IMMER (ohne Zeiger), wie im Laden unter den Würfeln — gemalt von `PackChoiceView`, groß genug, um die Zellen zu lesen; der Hover auf eine Netz-Zelle nennt im Auskunfts-Text der Ansicht die Zeile aus `DieNetView.hint_for` (dieselbe EINE Quelle wie überall). Das Netz erscheint, wenn sein Würfel landet.
5. **Die LICHT- und KLANG-SHOW steigert sich mit jedem Würfel** (Vorbild: die Schatztruhe aus Vampire Survivors — Idee, kein Nachbau): jeder Würfel, der die Schatulle verläßt, bekommt einen etwas größeren Moment als der vorige — heller, höher im Ton, mehr Licht (z. B. ein Lichtstrahl aus der Schatulle, ein Ring auf dem Grubenboden, steigende Töne auf der vorhandenen pentatonischen Leiter `ScoreAudio`/Tonart G-Moll, 120 BPM), und der LETZTE Würfel bekommt den Höhepunkt. Der Takt beschleunigt leicht. Klänge sind synthetisierte Platzhalter wie in `ScoreAudio` (ersetzbar durch Dateien), auf dem Bus `SFX`/`Score` des Bus-Layouts. Ein Klick überspringt bis zum Ende der Show (Endzustand zuerst — alle Würfel stehen sofort auf ihren Plätzen).
6. **Erst danach** zählt der Zähler die Wahlen hoch (wie bisher: Inhalt zuerst, dann die Zahl). Gewählt wird per Klick auf Würfel ODER sein Netz; der Gold-Saum liegt am Netz/Platz, der Würfel hebt sich ein Stück.
7. **Neu mischen**: die Würfel springen zurück in die Schatulle (oder lösen sich auf), der Deckel schlägt zu und springt wieder auf, die neuen Würfel kommen mit derselben Show heraus. Gebucht über `GameRun.reshuffle_pack_choice`.
8. **Bestätigen**: gebucht über `confirm_pack_choice`; die GEWÄHLTEN Würfel fliegen als Körper aus der Grube zur Schale/zum Vorrat (der Weg der ersten Fassung), die UNGEWÄHLTEN springen zurück in die Schatulle, der Deckel schließt, und der Tisch zieht die Schatulle ein (`PIT_CASE`, die Sektion der ersten Fassung). Danach greift der Zwang wie gehabt.
9. **Abbruch**: `_settle_pack_openings` bleibt der EINE harte Aufräum-Pfad (fliegende Würfel, Show, Klänge, Netze, Loch, Kamera — alles hart).

## Was bleiben darf / was weg kann

- Das Blender-Modell mit Scharnier-Deckel und Innenraum bleibt (die Würfel kommen ja aus ihm). Die Würfel-Plätze IM Innenraum (`case_interior_local`, `case_grid`, `case_slot_rect` in `PackChoiceView`) werden für die Wahl nicht mehr gebraucht — aufräumen, was tot ist (samt Tests).
- Die Layout-Regel der ersten Fassung (Kopf/Zähler/Knöpfe unter der Schatulle) entfällt; die Ansicht ordnet sich um die Aufstellung samt Netzen, die Schatulle steht oben am Grubenrand.

## Regeln

Wurzel-`CLAUDE.md`: *Ein Würfel wird nie zweimal gezeigt*, *Endzustand zuerst*, *EIN idempotenter Schreiber je Körper-Ort*, *ui/ fasst nie Körper an*, *Buchung vor dem Licht*, *EINE Größe je Ding*, das Bewegungs-Gesetz (Würfel, die aus der Schatulle springen, sind präsentierte Ware — wenn das eine neue Ausnahme ist, dort benennen).

## Tests und Doku

- Tests für das, was ohne scene_root prüfbar ist: `PackChoiceView` meldet bis 10 Plätze samt Netz-Rechtecken ohne Überlappung innerhalb der Grube, Netze erscheinen erst bei Landung (über ein Melde-Signal/Aufruf), Show-Stufen steigen mit dem Index (reine Funktion, z. B. Tonhöhe/Helligkeit je Würfel). scene_root-Abläufe per Probe prüfen und nach Änderung booten.
- Doku: die Abschnitte der ersten Fassung in Wurzel-`CLAUDE.md` (*Die PAKET-AUSWAHL*), `scripts/table/CLAUDE.md` und `scripts/ui/CLAUDE.md` auf den neuen Ablauf umschreiben, kurz und deutsch. `docs/plan_schatulle_auswahl.md` darf gelöscht werden.
