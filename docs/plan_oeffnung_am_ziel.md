# Plan: Öffnen am Ziel — Wählen IST Einsetzen (2026-11-17)

Spieler-Entscheid 2026-11-17 (Variante 2 „Das Paket reist zu seinem Ziel“, mit Abwandlungen). Löst die Paket-Öffnung aus `docs/plan_paket_lager.md` / `docs/plan_oeffnungs_flaeche_2.md` ab, soweit sie Wählen und Einsetzen trennt.

## Das Problem
Heute sind Wählen und Einsetzen zwei Entscheidungen an zwei Orten: man wählt Würfel auf der Öffnungs-Fläche, ohne den Vorrat zu sehen, und danach fährt die Kamera zum Raster (ZWANG) bzw. zu den Chips (EINBAU). Beim Modul-Paket entscheidet man sogar blind, welches gesteckte Modul verloren geht.

## Die Entscheidungen (Spieler)
1. **Karten- und Würfel-Pakete öffnen am SELBEN Ort: rechts neben dem Würfel-Pool.** Die Kamera rahmt je Art anders:
   - **Würfel-Paket**: Fläche ∪ Pool. Der Spieler wählt nicht nur, er setzt zugleich: jede gewählte Option kommt auf einen Pool-Platz, und der Würfel dort wird ersetzt.
   - **Karten-Paket**: Fläche ∪ Magazin. Der Spieler kann durch seine Karten blättern (Tablett wechseln, rollen, Netze lesen), um zu vergleichen.
2. **Jedes Paket öffnet sofort beim Kauf.** Es geht nicht mehr ins Lager. Das Lager bleibt vorerst stehen (Code und Möbel), bekommt aber nichts mehr — der Spieler entfernt es später, wenn der neue Ablauf sitzt.
3. **Modul-Pakete haben keine Auswahl.** Der Spieler bekommt 1–3 Module und behält alle; er entscheidet nur, wohin sie kommen und welches gesteckte Modul sie ersetzen.

## Gemessene Lage (1280 × 720, Display 5094 × 3180 px, Probe 2026-11-17)
| Ding | Display-px |
|---|---|
| Pool-Feld (Würfelsitze + Naht) | x 2916–3321, y 1995–2332 |
| Ausgabefach / Die-View-Säule / Krone | x ≈ 3340–3570, y 1995–2504 |
| **Öffnungs-Fläche heute** (`PIT_OPENING`) | x 3720–4260, y 1875–2653 (540 × 778) |
| Lager (`PackStore`) | x 3720–4260, y 1305–1875 |
| Werkstatt-Streifen | x 2916–3885, y 2506–2658 |
| Magazin-Grube (`PIT_MAGAZIN`) | x 2921–3882, y 2670–3039 |
| Kombi-Cluster | x 483–1846, y 1266–1914 |
| Wurfgrube (`PitWindow`) | x 1801–2872, y 1305–1875 |
| Hub (Laden) | x 1803–2871, y 2002–3127 |
| freier Filz rechts | x 4260–5094 |

**Folge für den Ort:** Die heutige Fläche liegt schon rechts neben dem Pool, nur getrennt durch die Säule des Ausgabefachs. Breiter darf sie kaum werden: der Würfel-Rahmen (Pool ∪ Fläche) ist an 16:9 genau dann noch **höhengebunden** (also maximal groß), wenn die Fläche höchstens **≈ 580 px** breit ist (778 px Höhe × 1,18 Rand × 16/9 = 1632 px sichtbare Breite, abzüglich 804 px Pool + Säule). Jede Verbreiterung verkleinert den Pool im Bild.

**Entschieden (A):** Grundriß und Ort der Fläche bleiben (540 × 778, x ab 3720). Neu ist allein, was neben ihr im Bild steht. Wird das Lager später entfernt, behält die Fläche ihren Platz; sie wächst NICHT in die Lücke nach oben, denn auch mehr Höhe macht den Rahmen größer und alles darin kleiner.

## Ablauf je Art

### A. Würfel-Paket — Wählen ist Einsetzen
1. **Kauf** (Laden, Phase SHOP): `GameRun` bucht Preis und Öffnung zugleich (Optionen, Wahlen, Glückswurf → `PackChoice` in `pending_pack_choices`). Das Paket fliegt als Körper im Trage-Bogen aus seinem Laden-Platz direkt in den Kopf der Fläche (Spieler-Zug → über dem Tisch). `_fly_into_store` entfällt für Käufe.
2. **Kamera**: temporärer Rahmen (kein Moduswechsel, Tilt gesperrt) auf **Pool-Feld ∪ Säule ∪ Fläche** (x 2916–4260, y 1875–2653). Die Lage davor wird gemerkt; dorthin geht es nach dem Bestätigen zurück (also in den Laden).
3. **Vorrat** (entschieden D): steht als KÖRPER-Ansicht (schwebende Würfel), nicht als Raster. Bei diesem Rahmen ist die Netz-Zelle des Rasters ≈ 5 Bildschirm-px groß und damit unlesbar (gerechnet aus 11,7 px am heutigen Zwangs-Rahmen ÷ 2,2). Die Oberseiten der Körper bleiben lesbar. Liegt das Raster gerade, wird es hart geschlossen (`_settle_deck_glass_hard`), bevor die Öffnung beginnt.
4. **Die Show** bleibt, wie sie ist: Schale fliegt ein, Haube springt auf, Würfel werden geschossen, gleiten in die Aufstellung, die Walze dreht die Wahlen aus.
5. **Zuordnen** (neu, statt „anwählen“):
   - **Ziehen**: eine Option aus der Aufstellung auf einen Pool-Würfel ziehen. **Tippen**: Option antippen (Gold-Saum), dann einen Pool-Würfel antippen. Wie überall gilt: gezogen ordnet zu, getippt wählt aus.
   - Ein **Entwurf**, noch nicht gebucht: die Option schwebt über ihrem Ziel-Sitz, der alte Würfel darunter wird rot gesäumt und dunkler („wird ersetzt“). Zurück geht es per Tipp auf den belegten Sitz, per Rechtsklick darauf oder per Zug zurück in die Aufstellung.
   - Höchstens `picks` Zuordnungen, je Sitz eine. Ein zweiter Zug auf einen schon belegten Sitz verdrängt die erste Option zurück in die Aufstellung.
   - **Vergleich**: wer über einen Pool-Würfel fährt, sieht in der Auskunftszeile der Fläche dessen Netz neben dem der gewählten bzw. überfahrenen Option (Seele, Material, Runen, Ladung). Die Quelle ist dieselbe wie bei Raster und Werkbank (`DieNetView.hint_for`).
   - Die Kopfzeile sagt „Setze bis zu K von N ein“; die Knöpfe sind **Einsetzen (k)** und **Neu mischen**. Neu mischen verwirft den Entwurf.
6. **Bestätigen**: `GameRun.confirm_dice_choice(choice, assignments)` bucht ALLE Zuordnungen atomar (`become` in die Pool-Instanzen, ein `pool_changed`). Danach die Zeremonie: jeder ersetzte Körper sinkt per Hebebühne aus seinem Sitz (der Tisch zieht ein), die neue Option setzt sich in einem kurzen Trage-Bogen hinein, ungewählte springen in die Schale zurück, und die Schale fährt unter den Tisch (`PIT_CASE`). Die Kamera kehrt heim.
7. **Weniger als K** einsetzen ist erlaubt (`valid_selection` läßt ≤ `picks` zu). Bei 0 heißt der Knopf „Nichts nehmen“.
8. **Das Podest**: steht der Zielwürfel der Werkstatt auf dem Podest, ist sein Pool-Sitz leer. Ziel ist dann sein Körper auf dem Podest; die Krone liegt im Rahmen (x 3367–3542, y 2410–2504). `become` schreibt in dieselbe Instanz, also bleibt das Podest gültig.
9. Der ZWANG samt Ausgabefach **bleibt** für alle anderen Würfel-Quellen (Boss-Prämie, Wett-Würfel, Schwarzmarkt-Essenzwürfel, Automaten-Würfel). Nur Paket-Würfel gehen nicht mehr durch `pending_dice`.

### B. Karten-Paket — Wählen mit dem Magazin im Blick
1. Kauf wie A.1 (die Kassette fliegt in die Fläche).
2. **Kamera**: temporärer Rahmen auf **Fläche ∪ Magazin-Grube** (x 2921–4260, y 1875–3039, höhengebunden). Gerechnet: eine Prägenetz-Zelle (35 Display-px) wird ≈ 18 Bildschirm-px groß, also lesbar (an der Werkstatt-Station heute ≈ 41).
3. **Das Magazin ist zum Blättern offen**: Sorten-Tasten, ▲▼, Rollen per Zug und das Anheben einer Karte zeigen ihr Netz. Stecken (Tipp auf eine Karte → Turm), Aufräum-Doppelklick und Rohling-Legen sind AUS. Das ist eine neue benannte Ausnahme zu *Sichtbar heißt bedienbar* (heute antwortet das Magazin auf Klicks nur an der WERKSTATT-Station).
4. **Hilfe beim Vergleich**: fährt der Zeiger über eine Option, wechselt das Magazin auf das Tablett ihrer Sorte (`WorkshopView.shelf_tray`, nur Anzeige; der Roll-Stand bleibt). Der Wechsel bleibt nach dem Schließen stehen.
5. Wählen und Bestätigen wie heute (`confirm_pack_choice` → `grant_pack`). Gewählte Karten reisen jetzt im **Trage-Bogen** als Körper direkt auf ihren Magazin-Platz (`next_pack_spot` / `arrival_anchor_px`); der Komet fällt weg, denn der Weg ist kurz und im Bild. Liegt das Ziel-Tablett verdeckt oder ist es hinausgerollt, gilt die bestehende Regel (an die Taste bzw. an den Grubenrand).

### C. Modul-Paket — keine Wahl, nur Platzieren
1. **Inhalt**: `ModulePack` gibt 1–3 Module, alle behalten. Entschieden (C): Klein 1 · Normal 2 · Groß 2 · Riesig 3, dazu ein Glückswurf +1 (mit `pack_luck`, Deckel 3). Die Stufe (Gewöhnlich…Legendär) zieht die Module wie bisher (`roll_contents`). Kein Neu mischen. Die Preise sind neu zu stimmen, denn statt einer Wahl aus 3–5 Optionen bekommt man jetzt alles (`OPTION_VALUE`-Formel).
2. **Kauf**: `GameRun.purchase_module_pack` zahlt, würfelt den Inhalt und legt ihn sofort nach `pending_parts` (`from_pack` true). Es gibt keine `PackChoice` mehr: Buchung vor dem Licht, und ein harter Abbruch verliert nichts (der Einbau steht beim nächsten Hinsehen wieder auf).
3. **Ort ist die WURFGRUBE**, direkt rechts neben dem Cluster (Fuge 169 px). Im Laden ist sie leer. Der ESD-Beutel fliegt aus dem Laden-Platz in die Grube, reißt an der Kerbe auf (`tear_open`), und die Module fallen als `ComboPartBody` in einer Reihe auf den Grubenboden.
4. **Kamera**: temporärer Rahmen auf **Cluster ∪ Grube** (x 483–2872, y 1266–1914). Das ersetzt `_frame_part_install` für Paket-Module.
5. **Einsetzen in beliebiger Reihenfolge**: ein Modul aus der Grube auf einen Steckplatz ziehen oder es antippen und dann den Platz. Der bestehende EINBAU-Hinweis bleibt, mit Geist und „Ersetzt X – X geht verloren“ unter dem Zeiger (`install_displaces`). Gebucht wird jeder Einbau sofort (`install_pending_part_at(index, key, slot)`), denn ein gestecktes Modul ist sichtbar endgültig.
6. Ist das letzte Modul gesteckt, fährt die Grube den leeren Beutel ein (Hebebühne), und die Kamera kehrt in den Laden zurück.
7. **Verwerfen (entschieden B)**: ein NEUES Modul darf zurück in den Beutel gezogen werden und ist dann weg. So zwingt ein volles Board nie, ein gestecktes Modul zu zerstören. Der Hinweis nennt beide Wege.

## Lager, Gewinn-Pakete, Warteschlange
- Kauf: `purchase_card_pack` / `purchase_dice_pack` öffnen sofort (`_open_pack`); `store_full` sperrt keinen Kauf mehr. Das Kleingedruckte (Erstattung) bleibt beim Kauf.
- Gewinn-Pakete der Nebenwetten öffnen ebenfalls sofort (`_award_pack` → immer `_open_pack`; der Weg „Lager voll → sofort öffnen“ wird zum einzigen Weg). Sie werden nach „Kassieren“ ausgezahlt; geöffnet wird, sobald der Laden steht (`_pack_opening_ready`).
- Die Öffnung ist MODAL. Wer ein zweites Paket kaufen will, schließt erst die erste. Mehrere Wett-Pakete reihen sich in `pending_pack_choices` und öffnen nacheinander; die Kamera springt dazwischen nicht in den Laden zurück.
- Lager: Grube, Rinnen und Code bleiben unangetastet stehen; sie bleiben leer. `debug_fill_store` kann bleiben. Die Fläche bleibt im Leerlauf als leere Vertiefung stehen (entschieden E); ihr Hinweis wird „Pakete öffnen sich hier beim Kauf“.
- Die Phasen bleiben, wie sie sind: geöffnet wird nur, wenn keine Runde läuft (`_store_unlocked`). Kaufen kann man ohnehin nur im Laden.

## Umsetzung nach Schichten

### core/ (`GameRun`, `PackChoice`) — reine Logik, zuerst
- `_purchase_stored` → `_purchase_open(pack, price, rng) -> PackChoice` (zahlen, Erstattung würfeln, `_open_pack`). Die Lager-Ablage entfällt für Käufe.
- `confirm_dice_choice(choice, assignments: Dictionary) -> Array` (option_index → pool_index). Prüft: Auswahl gültig (`valid_selection` auf den Schlüsseln), Pool-Indizes verschieden und im Bereich. Bucht per `become`, meldet einmal `pool_changed`, liefert je Paar `{option, pool_index, replaced}` (`replaced` = Kopie des alten Würfels, für die Zeremonie). Ungültig → nichts gebucht. `confirm_pack_choice` bleibt für Karten.
- `ModulePack.content_count(size, luck, factor, rng)`; `purchase_module_pack` gibt `Array[ComboPart]` zurück und stash't alle (`stash_part(part, true)`). `_open_pack` kennt keine Modul-Pakete mehr, und `PackChoice.KIND_MODULES` stirbt.
- `install_pending_part_at(pending_index, key, slot)`. `install_pending_part` ruft es mit 0 auf und bleibt für Wett-Module erhalten. `install_displaces` / `install_loses_displaced` bekommen den Index.
- `discard_pending_part(index)` (nur `from_pack`).
- Freie Hand, Glücksgriff, Beigabe, Zugabe und Verplombt gelten unverändert für Würfel und Karten. Für Module prüfen, was Beigabe/Zugabe jetzt bedeuten. Vorschlag: Zugabe +1 Modul, Beigabe/Verplombt wirkungslos. Die Klausel-Texte daraufhin glätten.

### ui/ (`PackChoiceView`) — malt und meldet, faßt keine Körper an
- Neuer Zustand ZUORDNEN für Würfel: `assignment_of(option)`, `set_assignment(option, seat_name)`. Saum, Marke „→ Platz n“ und Zähler „k von K eingesetzt“; die Knöpfe heißen „Einsetzen (k)“ bzw. „Nichts nehmen“.
- Vergleichszeile: `show_compare(option_def, pool_def)` in der Auskunft unten (zwei kleine Netze nebeneinander, Pfeil dazwischen).
- Modul-Modus raus (`bag_px`, `bag_seat_px`, Modul-Zweige in `open` / `_refresh`).
- Der Leerlauf-Text kommt von scene_root (bleibt `set_idle_text`).

### table/ / scene_root — Körper, Kamera, Gesten
- `_frame_opening(choice)`: Würfel → Pool-Feld ∪ Säule ∪ Fläche, Karten → Fläche ∪ `PIT_MAGAZIN`; beides über `camera_rig.frame_rect` mit eigener Marge (`PACK_DICE_FRAME_MARGIN`, `PACK_CARD_FRAME_MARGIN`). `_choice_home_handoff` an den ZWANG fällt weg.
- Kauf → Fläche: `_on_shop_pack_purchased` startet den Trage-Bogen zur Hülle der Fläche (`hull_seat_px` / `case_seat_px`) statt `_fly_into_store`. `_case_bought` wird die fliegende Hülle.
- Würfel-Zuordnung: Treffer auf Pool-Sitze über `DiceTrayView.SLOT_PICK_LAYER` (der eine Trefferweg), auf das Podest über den Bench-Körper. Pool-Umsortieren ist AUS, solange die Öffnung steht. EIN Schreiber `_sync_assign_bodies()` stellt die Entwurfs-Körper über ihre Sitze und setzt Saum und Dimmung der alten. Abbruch und Laufwechsel gehen durch `_settle_pack_openings`: der Entwurf verfällt, die Auswahl bleibt in GameRun und öffnet neu.
- Buchungs-Zeremonie: die ersetzten Sitze sinken (Hebebühnen-Sektion je Sitz wie beim SCHLUCK), die neuen Körper setzen sich. Endzustand zuerst: erst `confirm_dice_choice`, dann `_refresh_dice_trays` mit gehaltenen Sitzen, dann die Fahrt.
- Karten: `_screen_forwards_pixel` läßt das Magazin bei Karten-Öffnung Klicks nehmen (`_card_opening_browse()`); `pack_pressed` (stecken) und Rohling-Legen fragen dasselbe Bit und schweigen. Hover auf Option → `workshop.set_shelf_tray(sort)`. Die Lieferung wird `_carry_data_cell` auf den Magazin-Platz (Trage-Bogen, Endzustand zuerst).
- Module: `_open_module_bag_in_pit()` (Landefläche wie `_build_case_ground`, über dem Grubenboden), `_frame_part_install_pit()`, Pick der Grubenmodule über eine eigene Ebene (`ComboPartBody`-Kollider), Ziehen auf `SOCKET_PICK_LAYER`. `_part_install_forced` gilt weiter (modal, Würfel gehen vor). Der Beutel sinkt, wenn `pending_parts` leer ist.
- Der Grubenboden muß im Laden frei sein (Route-Karten liegen erst in IDLE, die Auszahlungs-Ablage ist vor dem Laden fort). In Phase 0 prüfen.

### Rückbau in dieser Welle (wirklich löschen)
- Modul-Paket auf der Fläche: `_open_module_bag`, die Modul-Zweige der Fläche, `part_delivery_comet` für Paket-Module.
- Paket-Würfel durch das Ausgabefach: `ausgabefach.expect_arrival` aus `_on_pack_choice_confirmed`, `_choice_home_handoff` / `_release_choice_handoff`, der Hand-over an `_sync_forced_exchange`.
- `PackChoice.KIND_MODULES` samt Tests.
- Veraltete Tests umschreiben statt auskommentieren: `test_pack_choice` (36 Stellen), `test_module_pack` (7), `test_combo_sockets` (23), `test_combo_parts` (9), `test_combo_parts_wave2` (1), `test_pack_choice_view` (5), `test_shop_controller` (5).

## Phasen (Feature-Welle → Plan + Opus-Agent, eine Phase nach der anderen)
0. **Messen**: Probe für die drei Rahmen (Würfel, Karten, Module): Bildschirm-px je Würfel-Oberseite, Netz-Zelle und Modul. Freier Grubenboden im Laden. Der Agent meldet die Zahlen, bevor er baut.
1. **core/**: sofort öffnen, `confirm_dice_choice`, Modul-Inhalt ohne Wahl, Einbau nach Index, Verwerfen. Unit-Tests.
2. **Würfel-Öffnung**: Flug in die Fläche, Rahmen, Zuordnen per Zug und Tipp, Vergleichszeile, Buchungs-Zeremonie.
3. **Karten-Öffnung**: Rahmen, Magazin-Blättern samt Ausnahme, Tablett folgt der Option, Trage-Bogen-Lieferung.
4. **Modul-Paket in der Grube**: Beutel, Reihe, freier Einbau, Rahmen, Einzug.
5. **Rückbau + Doku**: Wurzel-`CLAUDE.md` (PAKET-AUSWAHL, Layout rechts, *Sichtbar heißt bedienbar*: Magazin bei Karten-Öffnung, Pool-Sitze bei Würfel-Öffnung, Grube bei Modul-Öffnung; ZWANG: nur noch Nicht-Paket-Würfel), `scripts/ui|table|core/CLAUDE.md`, `docs/plan_paket_lager.md` mit „Öffnen abgelöst“, Obsidian-Seiten 45/46/47.

Test-Disziplin laut Wurzel-CLAUDE.md: während der Arbeit nur `-gselect` auf das gerade angefaßte Skript, die volle Suite EINMAL am Ende, Boot headless (scene_root ist angefaßt), jede Probe mit `--quit-after` und Vordergrund-`timeout`, kein `run_in_background` für Godot.

## Entschieden (Spieler, 2026-11-17)
- **A. Ort der Fläche**: Grundriß und Ort bleiben (540 × 778, rechts der Ausgabefach-Säule); die Säule bleibt stehen.
- **B. Modul verwerfen**: JA. Ein neues Paket-Modul darf zurück in den Beutel gezogen werden und ist dann weg (`discard_pending_part`). So muß kein gestecktes Modul geopfert werden.
- **C. Modul-Anzahl**: Klein 1 · Normal 2 · Groß 2 · Riesig 3, dazu ein Glückswurf +1 (Deckel 3).
- **D. Pool-Ansicht beim Würfel-Paket**: KÖRPER mit Vergleichszeile, kein Raster.
- **E. Fläche im Leerlauf**: bleibt dauerhaft als leere Vertiefung mit Hinweis („Pakete öffnen sich hier beim Kauf“).

## Umsetzung (2026-11-17)
Phasen 1–5 gebaut. Abweichungen und Messwerte (1280 × 720):
- **Würfel-Rahmen**: Pool ∪ Säule ∪ Krone ∪ Fläche, eine Würfel-Oberseite liest ≈ 33 Bildschirm-px (statt der gerechneten Raster-Zelle ≈ 5 px).
- **Karten-Rahmen**: Fläche ∪ Magazin samt Knopfleiste, eine Netz-Zelle ≈ 17–21 Bildschirm-px.
- **Modul-Rahmen**: Cluster ∪ Wurfgrube, eine Modulseite in der Grube ≈ 17,7 Bildschirm-px. Die Module fallen per Tween, nicht mit Physik.
- **Modul-Preise**: Grundpreise 10/18/20/24 (erwarteter Inhalt × `OPTION_VALUE`, ohne Wahl-Prämie). Zugabe gibt +1 Modul, Beigabe und Verplombt wirken nicht.
- **Tablett folgt der Option**: der Wechsel setzt den Roll-Stand des verlassenen Tabletts zurück (die bestehende Tablett-Regel), nicht „Roll-Stand bleibt“.
- **Podest-Würfel**: ein ersetzter Podest-Würfel schrumpft, statt per Hebebühne zu sinken (unter dem Podest liegt keine Sektion).
- **Beutel-Einzug**: eigenes Loch `TableScreen.PIT_BAG` (44, `MAX_PITS` 45), damit Schale und Beutel nie dasselbe Loch teilen.
- **Rückbau**: `_fly_into_store`, `_store_flying`, `_store_withheld`, `SideBet.awarded_stored`, `STORE_FULL_MARK`, `ShopController.part_text`, der Würfel-Zweig von `confirm_pack_choice` und der Modul-Modus der Öffnungs-Fläche sind gelöscht; das Lager selbst steht.

## Nachtrag (2026-11-17, Spieler-Wünsche nach dem ersten Blick)
- **E revidiert**: die Öffnungs-Fläche steht nur noch während einer Öffnung (`_opening_in_use`); leer sind Fenster, Loch und Vertiefung fort.
- Die Schale des Ausgabefachs steht nur, solange ein Nicht-Paket-Würfel wartet (Boss-Prämie, Wett-, Schwarzmarkt-, Automaten-Würfel).
- Würfel-Pakete mischen nicht mehr neu (kein Knopf, keine Energie-Anzeige); Karten-Pakete behalten Neu mischen.

## Nachtrag 2 (2026-11-17, Würfel-Pakete: Aufplatzen und Schiene)
- **Die Schale platzt.** Sie fliegt gekauft im Trage-Bogen an einen Punkt über der Schiene (4 Welt hoch), bläht sich und platzt: prozedurale Splitter, ein Blitz, ein Ring, danach ist sie fort. Die Würfel fallen mit echter Physik auf den Filz (Landefläche auf Tischhöhe), ein Glutkern pulst vor jedem möglichen Zusatz-Würfel und verlischt. Haube, Rütteln, Rücksprung und der Einzug der Schale (`PIT_CASE`, Platz 31 jetzt frei) sind gestorben, ebenso die Haube-API der `CardPackView`.
- **Die Schiene statt der Fläche.** Würfel-Pakete stehen ohne Schirm, Loch und Vertiefung auf dem Filz: je Option eine Reihe (Würfel links, Netz rechts), höchstens drei je Spalte, weitere Spalten rechts, oben bündig mit dem Vorrat und so hoch wie er. Darüber Walze und Zähler, darunter Auskunft, Knopf und Vergleich. Gemessen (1280 × 720): Schiene 445,7 × 337,5 Display-px ab x 3615, Teilung 112,5, Netz-Zelle 26,2.
- **Ungewählte** zieht der Tisch an ihrem Schienen-Platz ein (Schluck-Bahnen).
- **Wieder geöffnet** (nach dem harten Weg) platzt nichts ein zweites Mal: die Würfel liegen sofort auf der Schiene.
- Karten-Pakete behalten die Öffnungs-Fläche unverändert.

## Nachtrag 3 (2026-11-17, Runde 3 der Würfel-Öffnung)
- **Raster-Taste**: während jeder Paket-Öffnung steht sie nicht; sonst hängt sie jetzt unter der Schale des Ausgabefachs (x 3340, y 2098, 153 × 69 Display-px).
- **Die Die-View-Säule (`FachNetView`) ist gestorben.** Der INFO-SCHIRM unter dem Vorrat zeigt jetzt Text links und das Würfelnetz rechts: für den überfahrenen Vorrats-Würfel, den angehefteten und den wartenden Neuzugang des ZWANGS.
- **Anheften**: ein Tipp auf einen Vorrats-Würfel ohne gewählte Option heftet ihn an (er schwebt höher und bleibt im Schirm); im Schirm erklärt jede Netz-Zelle ihre Seite. Derselbe Tipp oder Rechtsklick löst.
- **Schiene näher am Vorrat**: links 1,5 Würfelkanten hinter dem Pool-Feld, x 3388,9 (vorher 3615,3); ihr Fuß endet bei y 2404, über der Krone (2410).
- **Kein Kopf mehr**: Name und „Setze bis zu …“ sind fort, die Walze steht rechts neben „Einsetzen (k)“. Die Vergleichszeile ist gestorben, der Schirm trägt die Auskunft des Vorrats.
- **Rahmen enger**: Pool ∪ Schiene ∪ Info-Schirm (∪ Krone, wenn ein Podest-Würfel steht): x 2848,9–3834,6, y 1994,8–2471,8 Display-px. Bei 1280 × 720 ist eine Würfel-Oberseite ≈ 46 Bildschirm-px (vorher ≈ 38), eine Netz-Zelle der Schiene ≈ 24 px (vorher ≈ 20) und eine Zelle des Schirm-Netzes ≈ 34 px.
