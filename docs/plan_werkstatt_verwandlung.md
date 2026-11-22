# Plan: Die VERWANDLUNG der Gleichung und der Tod der RASTER-Taste

Spieler-Entscheide 2026-11-22.

1. **Die Gleichungs-Zone verwandelt sich bei einer Paket-Öffnung in die Öffnungs-Fläche.**
   Solange ein Karten- oder Würfel-Paket fliegt, offen ist oder abgeht, versinkt die GANZE
   Gleichung (UPGRADES, „+“, Podest-Platte samt Die-View, „=“, ERGEBNIS, PRÄGEN, Überschriften,
   Leiterbahnen) im Tisch, und an ihrer Stelle steht die Öffnungs-Fläche. Danach kommt sie zurück.
2. **Die RASTER-Taste stirbt ersatzlos.** Ein DOPPELKLICK auf den Würfel-Vorrat öffnet das Raster.

Modul-Pakete (Wurfgrube) sind nicht betroffen.

## Teil A — Raster per Doppelklick

- `RasterSwitchView` (`scripts/table/raster_switch_view.gd`), `test/integration/test_raster_switch_view.gd`
  und in `scene_root.gd` der ganze Abschnitt *Der RASTER-UMSCHALTER* sterben
  (`raster_switch`, `_place_raster_switch`, `_raster_switch_rect(_px)`, `_raster_switch_live`,
  `_sync_raster_switch`, `_forward_raster_switch_mouse`, `_raster_area_px`, der Aufruf in
  `_forward_screen_mouse` bei Zeile ~11463 und in `_process` bei ~11828). `_toggle_deck_glass` darf bleiben,
  wenn noch gebraucht.
- `WorkshopView.drum_layout`: der Schlüssel `"raster"` und `raster_area_px()` sterben; PRÄGEN behält
  seinen Platz (`stamp_area` rechnet nicht mehr über `raster.size`).
- **Die Geste**: ein Doppelklick (linke Taste, `button.double_click`) auf das POOL-FELD
  (`_deck_glass_rect()` bzw. `_pool_row_px` in Display-Pixeln — nicht nur auf einen Würfel) öffnet das
  Raster über `_open_deck_glass(true)`, unter genau der alten Bedingung der Taste:
  `not _exchange_forced() and _fach_swap_live()`, nicht während `_pack_choice_modal()`, nicht in
  `workshop_close`/`die_focus`. Ton `&"raster_toggle"`.
- **Der erste Klick des Doppelklicks hat schon GEWÄHLT** (`_handle_tray_drag_input` → `_choose_workshop_target`).
  Der Doppelklick nimmt das zurück: beim Tipp wird der gewählte Index VOR der Wahl gemerkt
  (`workshop.chosen_index()`), der Doppelklick stellt ihn über `WorkshopView.choose_index` wieder her
  (bzw. `clear_choice`), bevor das Raster öffnet. Der zweite Druck darf KEINEN neuen Tray-Drag beginnen.
- Hinaus wie bisher: Rechtsklick (`_close_deck_glass`), Zurren hart. Die Hinweis-Zeile des Rasters
  braucht keinen neuen Text.
- Die Gleichung rückt NICHT um: das alte Raster-Feld über UPGRADES bleibt freier Filz.

## Teil B — Die Verwandlung

### Die Zone
`_opening_area_rect()` wird die ZONE: links ab `upgrades.position.x` (= Pool-Ende + `DRUM_SHELF_GAP`),
oben bündig mit der Pool-Reihe, so hoch wie sie, rechts bis zum bisherigen rechten Rand der
Öffnungs-Fläche (gemessen 4822,0 px bei 1280 × 720 — der Wurfplatz des Glückswürfels
`_luck_die_roll_px` und die Schale bleiben, wo sie sind; nichts über x 5094).
Gerechnet ~1300 × 487,5 Display-px. `PackChoiceView.area_beside` bekommt dafür die Gleichung statt
des Podests (reine Regel, Test anpassen).

- **Karten-Pakete**: `CARDS_PER_ROW` 6 — jede Größe (2–6) liegt in EINER Zeile. Prüfen, daß sechs
  liegende Karten samt Fugen in die Zonenbreite passen (sonst die Fuge schrumpfen, nie die Karte).
- **Würfel-Pakete**: die Schiene bleibt `RAIL_ROWS` 3 und steht LINKS in der Zone (nah am Pool),
  höchstens so breit, wie ihre Spalten brauchen (`rail_width_for`) — nicht auf 1300 px gezogen.
  Ihr Fuß darf weiter um die Naht unter die Zone reichen, nie bis an die Walzen-Nummern.

### Was fort ist, solange `_opening_in_use()`
- 2D (`WorkshopView`): `opening_shown` blendet jetzt ALLES der Gleichung aus und macht es klick-taub:
  beide Zeichen, UPGRADES/ERGEBNIS samt Überschriften, PodiumPlate, Die-View des Podests, das geparkte
  `_net`, ActionSeat und die `Traces`-Schicht. `hit_rects()` meldet die Gleichungs-Rechtecke dann nicht.
  `_sync_result_side` wird dafür umbenannt/erweitert (z. B. `_sync_equation_shown`).
- Körper (`scene_root`): der gewählte Würfel bleibt GEWÄHLT, fliegt aber heim und wartet in seinem
  Pool-Sitz — `_wanted_bench_die()` liefert null, solange die Öffnung die Zone braucht, und
  `_sync_bench_migration()` wird beim Beginn und beim Ende der Öffnung gerufen (wie beim Rohling).
  Der leere Puck `podium_stage` und ein aufliegender ROHLING (`bench_blank_cell`) sind unsichtbar und
  kommen mit der Zone zurück (der Rohling bleibt gewählt; sein Magazin-Körper bleibt zurückgehalten).
- **Folge**: der Podest-Würfel ist bei einem Würfel-Paket kein eigenes Zuordnungs-Ziel mehr — er sitzt
  im Pool und wird dort wie jeder andere ersetzt. Die Sonderwege fallen: der Podest-Zweig in
  `_assign_target_at`/`_sync_assign_bodies`, das SCHRUMPFEN eines ersetzten Podest-Würfels in
  `_confirm_dice_assignments`, das Podest in `_dice_opening_frame_px`.
- Eine laufende Prägung kann nicht mit einer Öffnung zusammenfallen? Prüfen: `_pack_opening_ready`
  muß `_transferring` abwarten (sonst ergänzen).

### Die Fahrt (Methode frei gewählt: der Mahjong-Deckel sinkt, tauscht, steigt)
Die bestehende Vertiefung (`PIT_OPENING`, `opening_pit`, `_opening_floor` in der Haut der Anzeige)
trägt die Verwandlung — der Boden zeigt immer das Bild der Anzeige an seiner Stelle:

1. Loch auf über der Zone, Boden bündig (y 0): nahtlos, er zeigt noch die Gleichung.
2. Boden sinkt auf `ZONE_DIP` (Vorschlag 0,5 Welt, `ZONE_SINK_TIME` ~0,18 s) — die Gleichung fährt
   sichtbar in den Tisch. Am tiefsten Punkt TAUSCHT das Bild (`opening_shown` kippt, Öffnungs-Fenster an).
3. Boden steigt (`ZONE_RISE_TIME` ~0,18 s): bei KARTEN auf −`PACK_AREA_DEPTH` (0,2, wie heute), bei
   WÜRFELN bündig auf 0, dann Loch zu und Boden fort (die Schiene steht ohne Schirm auf dem Filz).
4. Ende der Öffnung: derselbe Weg rückwärts.

Regeln:
- **Endzustand zuerst**: ein Zustand (`_zone_swapped` o. ä.) wird SOFORT geschrieben, der Tween fährt nur
  die Bodenhöhe und den Tausch-Zeitpunkt; EIN harter Schreiber (`_seat_zone_hard`) setzt Loch, Boden,
  `opening_shown` und Körper-Sichtbarkeit ohne Fahrt — gerufen aus `_settle_pack_openings`, Laufwechsel
  und wenn die Fahrt abbricht. Generations-Marke gegen alte Tweens.
- **Keine Wartezeit**: die Fahrt läuft WÄHREND des Trage-Bogens der Hülle bzw. des Aufblähens der Schale;
  die Öffnung selbst wartet nicht auf sie. Mehrere Öffnungen nacheinander (Wett-Gewinne): die Zone bleibt
  verwandelt, solange `run.current_pack_choice()` noch eine hat — kein Zurück-und-wieder-hin.
- `ZONE_DIP` flach halten: unter dem Podest stehen `chamber_pit`/`chamber_rig`/`chamber_floor`
  (Rahmenwürfel-Oberkante etwa −0,6). Solange die Zone verwandelt ist, sind sie unsichtbar bzw. bleibt
  der Boden darüber; prüfen, daß nichts durchsticht. Der Pool-Schacht: `_pool_cavity_reach` mißt an der
  Öffnungs-Fläche — mit der neuen linken Kante nachprüfen (Wandstärke gegen die Fuge `DRUM_SHELF_GAP`).
- Die Kamera-Rahmen (`_dice_opening_frame_px`, `_card_opening_frame_px`) messen an der neuen Zone.
- Der Zwang (`_sync_forced_exchange`) und die Schale bleiben unberührt.

## Runde 2 (Spieler-Entscheide 2026-11-22)
- **EIN Fußabdruck**: die Zone ist EINE Hebebühne; für Karten- UND Würfel-Pakete ist das Fenster
  genau die Zone, mit Schirm, in derselben flachen Vertiefung (Boden −`PACK_AREA_DEPTH`). Die Schiene
  ohne Schirm und ihr Fuß unter der Fläche sterben.
- **Karten**: zwei Reihen zu drei (`CARDS_PER_ROW` 3), der Block mittig; Kopf, Auskunft und Knöpfe
  lesen eine Spur größer.
- **Würfel im selben Stil**: Kopf (Name, Zähler erst nach dem Glückswürfel), Auskunft und Knopf
  „Einsetzen (k)“ im Schirm, dazwischen die Kacheln (Würfel + Netz) zu höchstens drei je Reihe.
- **Körper**: Würfel-Optionen, Landefläche und Aufplatzen auf dem Boden der Vertiefung;
  Ungewählte schrumpfen fort. Kamera: Pool-Feld ∪ Zone ∪ Info-Schirm ∪ Wurfplatz.

## Runde 3 (Spieler-Entscheid 2026-11-22)
- Die Zone ist eine ECHTE Hebebühne (`LiftShaftView`, `scene_root.zone_shaft`): die Gleichung samt
  ihrer Körper (`_zone_riders()`, eine Liste - künftige Körper der Vergleichs-Schirme kommen dort
  dazu) sinkt auf `ZONE_SHAFT_DEPTH` 3,0, unten tauscht das Bild, die Auswahl hebt BÜNDIG; zurück
  derselbe Weg. Keine Vertiefung mehr - Optionen, Landefläche und Aufplatzen auf Tischhöhe,
  Ungewählte zieht der Tisch wieder ein.
- Aufplatzen und fallende Optionen warten, bis die Zone steht; die Rückfahrt beginnt, wenn der
  letzte Körper der Auswahl fort ist. Eine Fahrt dauert 1,28 s.

## Tests
- Anpassen: `test/unit/test_workshop_drum_layout.gd` (kein `raster`), `test/integration/test_workshop_fixed_layout.gd`,
  `test/integration/test_pack_choice_view.gd` (`area_beside`, `CARDS_PER_ROW`, Schienenbreite).
- Neu (klein): `opening_shown` blendet alle Gleichungs-Knoten aus und `hit_rects()` schrumpft; die reine
  Zonen-Regel; sechs Karten passen in eine Zeile.
- `scene_root.gd` wird von Tests nie geparst: am Ende EIN Boot (`--quit-after 200`).

## Doku
Wurzel-`CLAUDE.md` und `scripts/ui/CLAUDE.md`, `scripts/table/CLAUDE.md`: die Absätze zu RASTER-UMSCHALTER,
Öffnungs-Fläche („rechts neben dem Podest“, 646,6 px, „liegt über =, ERGEBNIS, PRÄGEN“), Podest als
Zuordnungs-Ziel und „Sichtbar heißt bedienbar“ knapp auf den neuen Stand bringen, mit gemessenen Zahlen.
Kurz halten — ersetzen, nicht anhängen.

## Lauf-Regeln (verbindlich)
- Godot: `E:/Godot/Godot_v4.7-stable_win64_console.exe`, IMMER im Vordergrund mit Bash-`timeout`
  (Suite 600 s, Probe 120 s), NIE `run_in_background`, kein `sleep`-Polling.
- Während der Arbeit nur EINZELNE Skripte per `-gdir=res://test/integration -gselect=<name>` (bzw. `test/unit`);
  die VOLLE Suite genau EINMAL am Ende; danach `grep -c "Ignoring\|Parse Error"` aufs Log (muß 0 sein).
- `--import` EINMAL nach dem Löschen von `RasterSwitchView`.
- Jede Probe und jeder Boot mit `--quit-after N`; Sichtproben off-screen `--position 4000,2400`, gebündelt,
  Bilder nach `E:/Generated Images/Fumble/werkstatt_verwandlung/` — höchstens zwei Proben-Läufe.
- Kommentare: kurze deutsche Einzeiler, keine Aufsätze. Kein Commit.
