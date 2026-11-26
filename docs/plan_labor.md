# Plan: Das LABOR — ein Reaktor mit wechselndem Auftrag (2026-11-26)

Spieler-Wahl „R3 · SEKTOREN“ aus `tools/blender_labor_variants.py`, im Spielmaß `build_r4`
(Bilder `E:/Generated Images/Fumble/labor_reaktor_2026-11-26/` — `r4_schraeg.png`,
`r4_stationen.png`). Die runde Schale (Ø 13,2) paßt nicht unter den Schwarzmarkt (frei sind
rund 28 × 10,6 Welt), darum ist die Schale ein OVAL und die sechs Runden liegen als je drei
breite Leuchtfelder auf beiden Flanken. Maßgeblich sind Maße, Teile und Zustände von `build_r4`.

## Regel (Spieler-Entscheide 2026-11-26)

- Das Labor erscheint nach der ERSTEN bestandenen Boss-Runde (`stress_tests_passed >= 1`).
- Es trägt immer EINE von vier Stationen. Nach jedem ABGEHOLTEN Auftrag würfelt es eine ANDERE
  (nie dieselbe zweimal hintereinander). Kein Wechsel an Boss-Runden.
- Ein Auftrag: Einsatz hinein, START, der GLÜCKSWÜRFEL würfelt. Wartezeit = 6 − Augen Runden
  (`LABOR_ROUNDS` 6). Eine 6 heißt SOFORT fertig. Je `advance_round()` eine Runde weniger.
- Preis: der erste Auftrag des Laufs ist frei, danach 1, 2, 3 … Energie (= Zahl der bisher
  gestarteten Aufträge, steigt über den ganzen Lauf). Gezahlt beim START.
- EIN Auftrag zur Zeit. Fertig heißt: das Ergebnis wartet in der Kammer, bis es abgeholt ist.
- Der Glückswürfel WOHNT hier nicht: er fliegt zum Wurf her und danach heim. Sein Ergebnis
  bleibt als goldene Felder im Runden-Zähler stehen (Gold = Wurf, Violett = vergangene Runden).

### Die vier Stationen

| Id | Name | Einsatz | Während der Wartezeit | Ergebnis |
|---|---|---|---|---|
| `seele` | SEELEN-TRANSFER | zwei Vorrats-Würfel: QUELLE (mit Seele) und ZIEL | beide fehlen, ihre Pool-Sitze bleiben LEER (kein Leihwürfel) | das Ziel trägt die Seele der Quelle (überschreibend), die Quelle behält ihre; beide kehren auf ihre Sitze zurück |
| `charm` | CHARM-KOPIERER | ein eigener Charm | er wirkt nicht, sein Projektor steht dunkel und bleibt belegt | das Original wirkt wieder; die KOPIE braucht einen freien Projektor. Ist keiner frei, wartet sie in der Kammer — der Spieler verkauft einen Charm und holt sie dann |
| `modul` | MODUL-KOPIERER | ein gestecktes Modul | es wirkt nicht, sein Steckplatz bleibt belegt | das Original wirkt wieder; die Kopie geht nach `pending_parts` (der bestehende EINBAU wie ein Wett-Modul) |
| `karten` | KARTEN-PRESSE | 1 bis 6 Karten aus dem Magazin | sie sind fort | je Karte eine NEU gewürfelte Karte derselben Sorte, gewürfelt beim ABSCHLUSS mit `effective_luck() + 10` |

Karten-Presse: Rohling, verdichtete Karten, Katalysatoren und Operatoren sind kein Einsatz.
„Neu gewürfelt“ nutzt den Generator, den eine Karten-Paket-Option ihrer Sorte nutzt (Sorte =
`Pack.shelf_of`), die Größe mit dem Glück von oben — den vorhandenen Weg suchen, nichts erfinden.

## Welle 1 — core/ (keine Nodes)

Neu `scripts/core/labor.gd` (`class_name Labor`, `RefCounted`): Stations-Ids als `const`,
`STATIONS`, Name und Kurztext je Station, der Auftrag als Daten (`station`, `inputs`, `die_face`,
`die_value`, `rounds_left`, `done`), reine Regeln (`wait_for(value)`, `next_station(current, rng)`).
`to_dict`/`from_dict` wie `LuckDie` bereitlegen.

`GameRun`:
- Zustand `labor_station`, `labor_job` (null = leer), `labor_uses`; Signal `labor_changed`.
- `labor_open()`, `labor_price()`, `labor_inputs_valid(inputs)`, `can_start_labor(inputs)`.
- `start_labor_job(inputs, rng) -> bool`: prüft, zahlt, würfelt den Glückswürfel über den
  vorhandenen Weg (`_luck_roll`/`_luck_value`; das Güte-Glück gilt nicht), setzt `rounds_left`.
- `advance_round()` zählt herunter; bei 0 ist der Auftrag `done`.
- `labor_collectable()` und `collect_labor(rng) -> Dictionary` (was herauskam, für die Zeremonie):
  bucht das Ergebnis, leert den Auftrag, würfelt die nächste Station. Charm ohne freien Projektor:
  nicht abholbar.
- Die erste Station fällt, sobald das Labor öffnet (bei `grant_stress_reward`).
- **Würfel im Labor bleiben in `owned_pool`** (der Vorrat hat IMMER `POOL_SIZE` Einträge): sie sind
  nur GESPERRT (`labor_dice()`/`die_in_labor(die)`), und nichts zieht, wertet oder tauscht sie —
  die Stellen suchen, an denen eine Hand aus dem Vorrat entsteht, und sie dort auslassen; ebenso
  `exchange_pending_die`, `confirm_dice_choice`, Umsortieren und das Prägen.
- **Charm im Labor** bleibt in `owned_charms` an seinem Platz und ist unwirksam wie `dark_charm`
  (`_resolved_charms`, alle Stellen, die `dark_charm_slot()` fragen); er ist nicht verkäuflich
  und nicht verschiebbar.
- **Modul im Labor** bleibt gesteckt und ist unwirksam wie `is_part_disabled`; es ist nicht
  umsteckbar, und der Fumble-Verlust trifft es nicht.
- Karten im Labor verlassen `owned_packs` und liegen im Auftrag.
- Laufwechsel setzt alles zurück.

Tests `test/unit/test_labor.gd`: Öffnen nach der ersten Boss-Runde, Preisleiter, Wartezeit je
Augenzahl samt 6 = sofort, Herunterzählen, jede Station von Einsatz bis Abholung (samt
gesperrtem Würfel in keiner Hand, dunklem Charm, unwirksamem Modul, Karten-Sorte bleibt),
Charm-Kopie ohne freien Projektor, nächste Station ≠ aktuelle, ungültige Einsätze.
Doku: ein Abschnitt *Das LABOR* in `scripts/core/CLAUDE.md`.

## Welle 2 — Körper und Fenster (ohne GameRun, ohne scene_root)

`scripts/ui/labor_view.gd` (`LaborView`, ein Tisch-Fenster, das NICHTS malt — Muster
`SecretShopView`/`LuckStationView`): `UNITS` 28,0 × 10,6 (Welt), `PARTS` in Stations-Einheiten
(`dish`, `chamber`, `field0..5`, `name`, `start`, `status`), `part_rect`, unsichtbare Knöpfe über
Kammer und START (`chamber_pressed`, `start_pressed`), `set_state(state)` und daraus reine
Daten für den Körper (`body_state()`): Name, Zustand (`bereit`/`laeuft`/`fertig`), Felder
(je Feld `aus`/`wurf`/`runde`), Preis und ob bezahlbar, Status-Zeile („BEREIT“, „NOCH n“,
„FERTIG“, beim Laden „EINSATZ k/n“), Hinweistext je Teil (`hint_at(pixel)`).

`scripts/table/labor_body.gd` (`LaborBody`, prozedural wie `SecretShopBody`/`LuckStationBody`,
kein glb), nach `build_r4`:
- ovale MESSING-Schale 16,4 × 10,2 × 0,5, darin dunkler Feldgrund; mittig die runde Kammer
  (Innenradius 4,63) mit Messing-Kragen und hellem violett-weißem LEUCHTBODEN samt Punktraster;
- sechs RUNDENFELDER als Ringsektoren (Radius 5,4–7,6, je Flanke drei, ±38°, im Uhrzeigersinn
  ab rechts oben): Gold = Wurf, Violett (`CasinoStyle.ENERGY`) = Runde, aus = gedimmtes Violett,
  das noch als Feld zu lesen ist;
- GLASHAUBE (Zylinder, Höhe 2,0, fast durchsichtig, Stahlrand) nur solange der Auftrag läuft;
  sie senkt und hebt sich;
- rechts drei Chips mit leuchtendem Stich zur Schale: NAMENS-Schild, START-Taste (Text „START“
  und Preis mit dem Wort-Zeichen der Energie, gedimmt wenn nicht bezahlbar; „LÄUFT“; „FERTIG“
  grün), STATUS-Fenster; Druck „LABOR“.
- Einsatz in der Kammer in ECHTER Größe mit den Körpern, die der Schwarzmarkt zeigt (Würfel,
  Diskette, `ComboPartBody`, `DataCellView` — sechs Karten als Treppe): `set_items(items)`.
- Punkte für scene_root: `seat_point(i)` (Welt, wo Einsatz i liegt), `lid_point()` (wo der
  Glückswürfel würfelt: mittig auf der Haube), `start_point()`.
- `seat(state, hard)` ist der EINE Schreiber, `settle_hard()` der harte Weg, Endzustand zuerst.
  Helligkeit: sichtbar heller als der Schwarzmarkt, Eigenlicht knapp unter der Bloom-Schwelle.

Tests `test/integration/test_labor_view.gd`, `test_labor_body.gd` (Teile im Grundriß, Felder je
Zustand, Haube nur im Lauf, harter Weg schuldet nichts). Sichtprobe `tools/godot_labor_probe.gd`
nach `E:/Generated Images/Fumble/labor_spiel_2026-11-26/` (alle vier Stationen, drei Zustände).

## Welle 3 — scene_root und Tisch

- **Platz**: unter dem Schwarzmarkt, links bündig mit ihm, eine Fuge tiefer, `LaborView.UNITS`
  in Welt-Maßen; MESSEN und warnen, wenn es unter die Hub-Unterkante oder den Displayrand
  reicht. `TableScreen.place_labor_window`, das Deck kennt es als stehendes Bauteil ohne Druck
  und ohne ruhiges Feld (wie `KIND_MARKET`). Unsichtbar und klick-taub, bis das Labor öffnet;
  beim Öffnen erscheint es (schlicht, ein Aufleuchten genügt).
- **Station**: `CameraRig.Mode.LABOR` mit Klickzone wie der Schwarzmarkt; die Kamera steht dort
  still. Bedient wird nur an der eigenen Station (aus der Ferne wird der Klick zum Zoom),
  Hover und Hinweis antworten überall.
- **Laden** (Zustand `bereit`): ein Klick in die Kammer rüstet die WAHL. Die Kamera fährt an die
  Station des Einsatzes (Seele → POOL, Charm → CHARMS, Modul → COMBOS, Karten → WERKSTATT), und
  die nächsten Tipps auf gültige Dinge gehen ans Labor statt an ihre übliche Geste (früher Zweig
  in den vorhandenen Klick-Wegen). Seele: erst Quelle, dann Ziel. Karten: bis sechs, ein Tipp auf
  eine gewählte nimmt sie zurück, Rechtsklick schließt die Wahl ab. Rechtsklick ohne Wahl bricht
  ab. Gewähltes trägt den Gold-Saum (wo es ihn gibt), gebucht ist nichts. Danach fährt die
  Kamera ans Labor zurück, der Status nennt „EINSATZ k/n“, START leuchtet.
  Die Wahl ist nur möglich, wo der Vorrat bzw. die Steckplätze bearbeitbar wären
  (`_pool_editable`, `_part_moves_live`-Bedingung ohne Stations-Teil), nie im Zwang, nie in einer
  Paket-Öffnung.
- **START**: `GameRun.start_labor_job` bucht zuerst. Dann fliegt der Einsatz im Trage-Bogen in
  die Kammer (Spieler-Zug; die vorhandenen Trage-Helfer nutzen, wo keiner paßt, genügt ein
  schlichter Bogen des Körpers), die Haube senkt sich, der GLÜCKSWÜRFEL fliegt auf die Haube
  (`LUCK_LABOR` als vierter Ort neben HOME/ROLL/PIT, derselbe EINE Schreiber), würfelt auf die
  gebuchte Seite (`roll_to`), die goldenen Felder leuchten nacheinander auf, er fliegt heim.
  Ein Klick springt ans Ende. Bei einer 6: alle Felder gold, Haube gleich wieder auf, „FERTIG“.
- **Lauf**: die Pool-Sitze der Labor-Würfel bleiben leer (`DiceTrayView.seat_shows`), der
  Projektor des Charms steht dunkel und leer, das Modul im Chip ist gedimmt bzw. fort; die
  Körper liegen in der Kammer. Je Runde leuchtet ein violettes Feld mehr.
- **Abholen** (Zustand `fertig`): Klick in die Kammer → `collect_labor` bucht, dann fliegen die
  Körper heim (Würfel auf ihre Sitze; Diskette samt Kopie zu ihren Projektoren; Modul heim, die
  Kopie in den bestehenden EINBAU; Karten ans Magazin wie eine Lieferung). Charm ohne freien
  Projektor: der Status sagt „PROJEKTOR FREI MACHEN“, nichts geschieht. Danach wechselt der Name
  auf die nächste Station.
- Harte Wege: Laufwechsel, unsichtbar, `_table_operable()` falsch — alles steht im Endzustand,
  die Wahl ist verworfen, der Glückswürfel zu Hause.
- `CLAUDE.md`: ein Punkt *Das LABOR* in den globalen Invarianten, der Glückswürfel-Flug als
  Teil der dritten benannten Ausnahme, die Stations-Regel unter *Sichtbar heißt bedienbar*;
  Abschnitte in `scripts/table/CLAUDE.md` und `scripts/ui/CLAUDE.md`.

## Lauf-Regeln für jede Welle

Nur einzelne Skripte per `-gselect`, KEINE volle Suite (die fährt die Session einmal am Ende),
jeder Godot-Start im Vordergrund mit `timeout` und `--quit-after`, nie `run_in_background`,
`--import` einmal nach einer neuen `class_name`. Kommentare: kurze deutsche Einzeiler.
Nichts committen.
