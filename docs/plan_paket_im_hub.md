# Plan: Die Paket-Öffnung zieht in den HUB (Spieler-Wunsch 2026-11-12)

Das gekaufte Paket fliegt an die obere Mitte des Hubs, der Laden tritt zurück, und die GANZE Öffnung (Schatulle, Auswurf, Aufstellung, Güte, Walze, Wahl) spielt auf dem Hub-Display. Heute spielt sie in der Wurfgrube, und die Kamera fährt dafür dorthin.

## 1. Gemessen (Probe `hub_geo_probe.gd`, 1280 × 720, off-screen)

| | Welt | Display-px |
|---|---|---|
| Pixel je Welt-Einheit | 37,5 | |
| HUB (Fenster) | 28,5 × 30,0 | 1068,8 × 1125,0 |
| Wurfgrube (Fenster) | 28,56 × 15,2 | 1071,0 × 570,0 |
| Hub-Anker (Welt) | (−26, 0, 0) | |

- Der Hub ist **gleich breit** wie die Grube und **fast doppelt so hoch** (1125 gegen 570 px). Die Breite gewinnt man nicht, die Höhe schon.
- Die Ladenseite füllt den ganzen Hub (Kinder `Frame` und `ShopPanel`, beide 1068,8 × 1125). Kopf (Titel, Sortiment sperren, Geld) und Fuß (Blättern, Fertig) liegen darin; ihre genaue Höhe ist NICHT gemessen. Schritt 0 der Welle misst sie.
- **Schätzung** der Aufstellungs-Höhe im Hub: Seite 1125 minus Rand und Kopf mit Schatulle (~200 px, dieselben Konstanten wie in der Grube: `HEAD_MIN_UNITS`) minus Auskunfts-Zeile (~60 px) ≈ **800 px gegen ~330 px heute**. Zehn Würfel in zwei Reihen bekämen damit etwa 2,4-mal so hohe Blöcke und deutlich größere Netze.
- Die Grube hat einen echten Boden (`DicePit.FLOOR_Y` −1,0) und 16 hohe Kraftfeld-Wände auf Ebene 1. **Der Hub hat keine Physik**: er ist die Tischfläche bei Y = 0. Die Wegwerf-Würfel (`PACK_LAUNCH_LAYER` 1 << 9, Maske `1 | PACK_LAUNCH_LAYER`) fänden dort nichts, worauf sie landen.
- Der Hub-Zoom steht schon (`CameraRig.Mode.HUB`, `configure_hub_target`): die Kamera MUSS für die Öffnung nicht mehr fahren.
- Vorbild für „Ware steht auf einer Hub-Seite“: die AUSZAHLUNGS-SEITE (`PayoutLedgerView`, `table_screen.hub.attach_panel`, Loch `PIT_PAYOUT` im Hub-Display, Körper stellt `scene_root`).

### Schritt 0 und Umsetzung, gemessen (2026-11-12, Probe `hub_measure0.gd`/`hubopen_probe.gd`, 1280 × 720)

- Hub in Display-Pixeln bei (1802,6 | 2002,3), 1068,75 × 1125,0; obere Mitte in Welt (−11, 0, 0).
- Ladenseite (lokal im Hub): Kopf `Header` y 21–88 (67 px), Fuß `Footer` y 1065–1132 (67 px, ragt 7 px über den Rand), dazwischen Charms 100–378, Würfel 390–733, Gravuren 745–971, Auskunfts-Band 983–1053. Weil der Laden für die Öffnung ganz abtritt, gehört der Öffnung die GANZE Seite; Kopf und Fuß des Ladens begrenzen nichts.
- Öffnungs-Seite: u = 10,69 px (wie in der Grube), Schatulle oben mittig bei lokal (534,4 | 94,1) (`HEAD_TOP_UNITS` 2,5 — bei 1,0 ragte sie über den oberen Hub-Rand), Aufstellungs-Fläche lokal (21,4 | 191,3), **1026,0 × 873,8 px** (Grube: ~1000 × ~330).
- Ein Block wächst höchstens auf `block_max_height()` = 278,7 px (Platz + Netz in voller Zelle + Fuß), sonst stünde ein Würfel oben in einem 870 px hohen Block.
- Netz-Zelle (Display-px, mit den neuen Konstanten `NET_CELL_MAX_UNITS` 5,0 / `BLOCK_MAX_UNITS` 24): 1 Würfel 53,4 · 4: 53,4 · 6: 35,8 · 7: 53,4 · 10: **43,5** — auf der Grubenfläche (1040 × 530) wären es 52,0 · 52,0 · 34,8 · 14,1 · 14,1.
- `LINEUP_TILT_TRIM` 0,45 → 0,6: die Hub-Kamera ist steiler geneigt, der Würfel ragte sonst über die Oberkante seines Blocks (0,8 setzte ihn auf sein Netz).
- Landefläche: Boden über `landing_rect_px()` (Aufstellungs-Breite, vom Kopf bis über die Auskunfts-Zeile), Würfel liegen gemessen bei y = 0,60 (halbe Kante), keiner verläßt die Seite.
- Falle im Kauf-Bild: die Ladenseite sortiert ihre Container nach einem Kauf erst in den Folgebildern um; ein sofortiger Abgang maß die Gravuren-Reihe 290 px zu tief (Loch unter dem Fuß). Darum wartet die Öffnung `PACK_SHOP_SETTLE_FRAMES` (3) Bilder ruhigen Laden ab.

## 2. Ziel und Grenzen

- Kauf (und Wett-Gewinn) eines Karten- oder Würfel-Pakets: die Laden-Auslage tritt ab, eine OFFNUNGS-SEITE des Hubs übernimmt, die Schatulle (bzw. bei Karten-Paketen die Hülle) fliegt an die obere Mitte der Seite.
- Alles Weitere (Regeln, Buchung, Walze, Güte, Neu mischen, Wahl) bleibt, wie es ist: `GameRun`, `PackChoice`, `DicePack`, `CaseShow` ändern sich nicht. Gebucht wird weiter beim Kauf und beim Bestätigen.
- Nach der Wahl kehrt der Laden zurück, wie er war (Seite, `*_bought`-Flags, Sortiment-Sperre, ohne neu zu würfeln); danach greift der ZWANG wie heute (Kamera an den Vorrat).
- Beide Paketarten ziehen um (Karten und Würfel), damit es EINEN Ort für die Geste gibt.
- Nicht Teil der Welle: neue Spielregeln, neue Töne, neue Modelle.

## 3. Entscheidungen (mit Empfehlung)

1. **Boden der Würfel-Physik im Hub: eine eigene Landefläche.** Ein unsichtbarer Boden (`StaticBody3D`, Oberkante auf Tischhöhe) und Wände ringsum, alles ausschließlich auf `PACK_LAUNCH_LAYER`, gebaut beim Öffnen, abgebaut im EINEN harten Weg. Die Würfel LIEGEN dann auf dem Hub-Glas, genau wie die Ware im Laden. (Alternative, verworfen: ein großes Loch im Hub-Display mit echter Vertiefung — viel Aufwand und der Hub-Hintergrund verschwände.)
2. **Die Seite ist eine eigene Hub-Seite** (`PackOpeningPage`, Nachfolger-Rolle von `PackChoiceView` als Hub-Kind über `attach_panel`), kein Fenster über der Grube. Sie malt Namen, Zähler, Walze, Plätze, Netze, Knöpfe und meldet Rects in Display-Pixeln; die Körper stellt `scene_root` (ui/ fasst nie Körper an).
3. **Der Laden TRITT AB per Schluck-Zeremonie** (Netz-Absorption plus `exit_all`), nicht per hartem Ausblenden. Dafür braucht der Laden eine neue Funktion `suspend()` = Abgang wie `close()`, aber OHNE `closed`-Signal und ohne Rundenfortschritt; zurück kommt er über das vorhandene `reopen()` (Grad RISE, weil die Bucht leer ist).
4. **Die Kamera bleibt auf dem Hub.** Entfällt: `frame_rect`, `_choice_home`, Rückfahrt. Bleibt: `set_tilt_locked(true)`.
5. **Karten-Pakete ziehen mit.** Ihre Optionen liegen flach auf der Hub-Seite (kein Auswurf, die Hülle öffnet sich, Karten gleiten auf ihre Plätze).

## 4. Schritte

**Schritt 0 – Messen (kurz, zuerst):** Probe mit ausgeblendeter Ladenseite; Höhe von Kopf und Fuß, nutzbares Rechteck der Aufstellung, Position der oberen Mitte, Abstand Laden-Bucht → obere Mitte. Ergebnis in diese Datei unter *Gemessen* nachtragen.

**Schritt 1 – Hub-Seite und Koordinaten:**
- `PackChoiceView` wird als Hub-Seite angehängt (`table_screen.hub.attach_panel`), `_place_pack_choice_view` nimmt das Hub-Rechteck statt des Gruben-Fensters.
- Achtung Falle: `slot_centers()` und `case_seat_px()` addieren `position`; bei einer Hub-Seite ist `position` (0, 0) im Hub, die Meldungen brauchen aber Display-Pixel → mit `global_position`/Hub-Versatz rechnen. Ein Test hält fest, dass die gemeldeten Plätze in Display-Pixeln stehen.
- Die Layout-Konstanten (`LINEUP_ONE_ROW`, `BLOCK_MAX_UNITS`, `NET_CELL_MAX_UNITS`) für die höhere Fläche prüfen: bei zehn Würfeln in zwei Reihen darf die Netz-Zelle wachsen.

**Schritt 2 – Laden tritt ab / kehrt zurück:**
- `ShopController.suspend()` und der Weg `_sync_pack_choice` → `_open_pack_choice`: die Bedingung `charm_shop.visible and not leaving` entfällt zugunsten „Laden ist in Ruhe abgetreten“ (`_vitrine_leaving` und `_vitrine_curtain` beachten).
- Rückkehr: `reopen()` über den bestehenden Weg; `_settle_pack_openings` (harter Weg) stellt den Laden ebenfalls wieder her.
- Test: Seite, `*_bought`, Sortiment-Sperre und Blätter-Seite sind nach Öffnung und Wahl byteweise dieselben.

**Schritt 3 – Kauf-Flug und Schatulle im Hub:**
- `_open_dice_case`: Ziel ist der gemeldete Sitz auf der Hub-Seite (`pixel_to_world`), `arc_to` aus der Laden-Bucht; `frame_rect` entfällt.
- Die Landefläche (Entscheidung 1) steht, bevor der erste Würfel fliegt; Wände an die Ränder der Aufstellungs-Fläche gemessen in Welt-Einheiten.
- `PIT_CASE` (Sektion, die die Schatulle einzieht) im Hub-Display: gleicher Slot, anderer Ort; prüfen, dass beim Ein- und Auffahren kein Loch stehen bleibt (`clear_pit`).

**Schritt 4 – Karten-Pakete:** `_open_pack_choice` für Karten auf die Hub-Seite umstellen (Hülle oben, Optionen als liegende Karten auf den Plätzen, `_data_cell_seat`).

**Schritt 5 – Abgang:** bestätigt: Gewählte fliegen als Körper in die Schale (`fach_delivery_comet`/`_fly_case_die`), die Ungewählten springen zurück, die Sektion zieht die Schatulle ein, der Laden kehrt zurück; der ZWANG holt dann die Kamera an den Vorrat. Der Flug Hub → Schale ist lang (Hub x = −26, Pool weiter weg); die ZWANG-Kamera startet im Bild der Buchung, also sieht der Spieler die Würfel schon unterwegs. Sichtprobe nötig.

**Schritt 6 – Tests, Doku, Aufräumen:** Tests (`test_pack_choice_view`, `test_case_show`, neue Tests für Laden-Rückkehr und Hub-Koordinaten), Suite einmal, Boot (scene_root wird angefasst), Docs: Wurzel-`CLAUDE.md` (Die PAKET-AUSWAHL), `scripts/ui/CLAUDE.md`, `scripts/table/CLAUDE.md`, Obsidian-Seite 46. Obsolete Passagen streichen (Grube, Kamera-Rahmen).

## 5. Risiken

- **Physik auf dem Glas:** Würfel rollen flach über das Display; ohne sauberen Boden stecken sie im Display oder springen weg. Landefläche früh mit einer Probe prüfen (Reibung/Abprall wie `DicePit.FRICTION` 0,4, `BOUNCE` 0,25).
- **Laden-Zustand:** der meiste Aufwand. Jeder Pfad, der den Laden sonst schließt (Titel, Lexikon, Laufwechsel), darf eine laufende Öffnung nicht kreuzen.
- **Reihenfolge:** Kauf → `purchase_*_pack` bucht sofort, während der Laden noch abtritt; `_choice_open` blockt weitere Käufe, das gilt weiter.
- **Spiegelung:** Würfel und Schatulle sollen auf dem Hub-Glas nicht doppelt erscheinen (`mark_reflective` wie bei der Ware).
- **Camera-Moduswechsel:** der Spieler kann mitten in der Öffnung wegzoomen wollen; die Öffnung ist modal (`_pack_choice_modal`), das bleibt.

## 6. Abnahme

- Würfel-Paket kaufen → Laden tritt ab, Schatulle fliegt oben in die Mitte, Öffnung läuft im Hub, wählen, Laden kehrt unverändert zurück, ZWANG funktioniert.
- Dasselbe mit Karten-Paket und mit einem Wett-Gewinn-Paket.
- 10 Würfel: zwei Reihen mit mindestens so großen Netzen wie in der Grube, kein Überlappen (Tests je Anzahl 1–10).
- Neu mischen spielt alles neu; ein Klick springt ans Ende; Laufwechsel mitten in der Öffnung räumt hart (Löcherliste leer, Boden und Wände fort, Laden steht).
- Volle Suite 0 Ignoring/Parse Error, Boot ohne SCRIPT ERROR.

## 7. Offene Fragen an den Spieler

- Soll der Laden beim Zurückkehren sichtbar „aufdecken“ (wie bei Wiedereintritt) oder sofort stehen?
- Sollen Geld und Energie während der Öffnung als kleine Zeile auf der Seite stehen (die Energie braucht „Neu mischen“)?
