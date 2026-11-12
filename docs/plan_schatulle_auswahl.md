# Plan: Die Würfel-Auswahl IN der Schatulle (2026-11-10)

Spieler-Wunsch. Baut auf der Paket-Auswahl auf (`scene_root`s *Die PAKET-AUSWAHL*, `PackChoiceView`, `CardPackView`, `tools/blender_dice_case.py` → `assets/models/hardware/dice_case.glb`). Gilt NUR für WÜRFEL-Pakete; Karten-Pakete (Kassette) bleiben, wie sie sind.

## Wunsch des Spielers (wörtlich übersetzt)

„Wenn der Spieler ein Würfel-Paket kauft und es geöffnet wird, soll das Paket in die Wurfgrube fahren und sich öffnen. Die Würfel bleiben die ganze Zeit IN dem Paket, und erst wenn der Spieler seine Wahl bestätigt, verschwindet das Paket im Tisch, und die Würfel fahren zum Würfel-Vorrat, wo sie eingesetzt werden.“

## Ablauf (neu, nur Würfel-Pakete)

1. **Kauf** wie bisher (gebucht: Preis, Optionen, Wahlen). Die Schatulle verläßt ihren Platz in der Laden-Bucht und FLIEGT zur Wurfgrube. Sie ist vom Spieler gekauft, also reist sie als KÖRPER über dem Tisch (Trage-Bogen, Bewegungs-Gesetz in der Wurzel-`CLAUDE.md`) — kein Komet, kein neuer Körper über der Grube. Startpunkt ist ihr echter Platz in der Bucht (der Kauf-Abgang der Bucht `run_take` darf für Würfel-Pakete entfallen oder durch den Abflug ersetzt werden — EIN Körper, nie zwei zugleich sichtbar). Die Kamera fährt wie heute an die Grube, rahmt aber die SCHATULLE eng genug, daß die Würfel darin gut lesbar sind (temporärer Rahmen, `frame_rect`, Lage davor gemerkt).
2. **Öffnen**: in der Grube gelandet, klappt der DECKEL auf (Scharnier an der Langseite gegenüber der Schließe). Dafür braucht das Blender-Modell einen HOHLEN Boden (Innenraum mit dunkler Samt-Auskleidung, die Würfel liegen darin) und einen Deckel, dessen Ursprung auf der Scharnierachse liegt (samt allem, was am Deckel sitzt: Augen, Lasche). Das Modell bleibt im Roh-Maß und mit der Naht als eigenem Objekt (Sortenfarbe). Skript `tools/blender_dice_case.py` erweitern, neu exportieren, Render zur Kontrolle.
3. **Die Würfel liegen IN der Schatulle**, von Anfang an (sie sind beim Öffnen schon da, nichts fällt herein und nichts verläßt die Schatulle). Bis zu 6 Optionen (Beigabe/Beipack) müssen Platz haben — in Reihen im Innenraum. Größe nach *EINE Größe je Ding*: Würfel in `DiceTrayView.DIE_SCALE`, Schatulle in `CASSETTE_SCALE`; paßt es nicht, wird der INNENRAUM/die Anordnung angepaßt, nie ein Maßstab. Die Würfel sollen ihre obere Seite gut lesbar zeigen (wie heute die Geister-Würfel der Auswahl).
4. **Zähler und Wahl** wie heute (`PackChoiceView`: Zähler, Auskunft, Nehmen, Neu mischen). Gewählt wird per Klick auf den Würfel IN der Schatulle — `PackChoiceView` meldet weiter die Plätze in Display-Pixeln (ui/ faßt nie Körper an), aber für Würfel-Pakete liegen diese Plätze jetzt auf dem gemeldeten INNENRAUM der Schatulle (scene_root meldet ihn als Display-Rechteck, das `apron_bottom`-Muster); gewählte Würfel heben sich ein Stück (wie heute) und tragen den Gold-Saum. Der Rest der Ansicht (Kopf, Zähler, Knöpfe) darf an seinem Platz bleiben, solange er nicht über der Schatulle liegt.
5. **Neu mischen**: Deckel klappt zu, die Würfel tauschen verdeckt, Deckel klappt wieder auf. Gebucht wird wie heute über `GameRun.reshuffle_pack_choice`.
6. **Bestätigen**: gebucht wie heute (`confirm_pack_choice`). Dann:
   - die GEWÄHLTEN Würfel verlassen die Schatulle und fahren zum Vorrat — als KÖRPER (Trage-Bogen, wie Pool ⇄ Podest, `FloatingDie.carry_to` oder dieselbe Bogen-Grammatik), Ziel ist die Schale (`AusgabefachView`) bzw. der Weg, auf dem der ZWANG sie einsetzt. Kein zweiter Körper: wo ein Würfel landet, übernimmt der Körper der Schale bzw. das Raster, im selben Bild (`expect_arrival`/`deliver`). Der Zwang (`_sync_forced_exchange`) holt danach wie heute die Kamera an den Vorrat und setzt sie der Reihe nach ein; danach zurück in den Laden.
   - die Schatulle samt UNGEWÄHLTEN Würfeln klappt zu und VERSCHWINDET IM TISCH: der Tisch zieht sie ein (EINZUG = Hebebühne, wie der SCHLUCK `_swallow_dice` bzw. `LiftShaftView.run_take`: eine Sektion unter ihr öffnet, senkt sie ein, Loch zu). Löcherliste: einen freien Platz benutzen oder einen benennen, beide Shader im Gleichschritt (siehe `TableScreen.MAX_PITS`).
7. **Abbruch** (Laufwechsel): `_settle_pack_openings` bleibt der EINE harte Aufräum-Pfad — Schatulle, Würfel, Loch, Kamera, alles hart weg bzw. heim. Endzustand zuerst, Generations- und Lauf-Marken wie im bestehenden Code.

## Regeln, die gelten

- *Ein Würfel wird nie zweimal gezeigt*, *Endzustand zuerst*, *EIN idempotenter Schreiber je Körper-Ort*, *ui/ fasst nie Körper an*, *Buchung vor dem Licht* (Wurzel-`CLAUDE.md`).
- Das Bewegungs-Gesetz: was der Spieler gekauft hat, fliegt ÜBER dem Tisch; was der Tisch einzieht, fährt UNTER ihn. Falls eine neue Ausnahme nötig wird, in der Wurzel-`CLAUDE.md` benennen.
- Karten-Pakete und ihre Auswahl bleiben unverändert (Test dafür).

## Tests und Doku

- Unit/Integration: Schatulle hat Scharnier-Deckel und Innenraum (Knoten), Würfel-Optionen liegen innerhalb des Innenraums (Welt-Rechteck), Bestätigen läßt Gewählte in `pending_dice` landen und räumt Schatulle und Loch ab, `_settle_pack_openings` räumt mitten in jeder Phase hart ab (kein offenes Loch, kein verwaister Körper). Tests parsen `scene_root.gd` nie — nach Änderung einmal headless booten.
- Doku kurz und deutsch: `scripts/table/CLAUDE.md` (Abschnitt Paket-Hülle), `scripts/ui/CLAUDE.md` (PAKET-AUSWAHL), Wurzel-`CLAUDE.md` *Die PAKET-AUSWAHL*.
