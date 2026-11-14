# Plan: Paket-Lager als RINNEN-Regal (2026-11-14)

Spieler-Wunsch: das Lager ist zu groß (heute 1354,6 × 570 Display-px, drei Gruben zu 2 × 3 Plätzen mit zweiter Lage). Gewählt ist Vorschlag „Lager A": die Pakete STEHEN HOCHKANT in Rinnen wie die Chips im Chip-Tray, man sieht von oben nur ihren RÜCKEN — eine schmale Zeile, die das Tray fortsetzt.

## Entscheidungen
1. **Drei Rinnen ÜBEREINANDER** in einer Grube-Fassung rechts neben dem Chip-Tray (Fuge wie heute, `LAYOUT_SIZE.x * 0,005`), bündig mit Tresen und Tray (Höhe 570 px, Welt y 34,8–50,0). Von oben nach unten: Karten, Würfel, Module (= `GameRun.LANE_*`). Jede Rinne läuft in Bild-x (Welt Z), ohne Neigung.
2. **Ein Paket steht hochkant, Fläche quer zur Rinne** (wie ein Chip/ein Buch im Regal): entlang der Rinne nimmt es nur seine DICKE ein (Karten-Kassette wächst je Größe in die Dicke — die Paketgröße liest sich so von selbst), quer zur Rinne seine KURZE Seite, in die Tiefe die LANGE. Es steckt ganz in der Grube, die Oberkante knapp unter der Schnittkante (wie heute `PACK_STORE_CLEAR`). Die Größe ändert sich NICHT (EINE Größe je Ding) — nur die Lage. Paßt die Tiefe nicht, darf das Paket zur Hälfte überstehen; Agent entscheidet nach Sichtprobe, Ziel: der Rücken liest an der CHIPS-Station.
3. **Der Rücken muß die Art tragen**: Sorte (Naht/Saum-Farbe), Güte (Schatulle) bzw. Seltenheit (Beutel). Liest das bestehende Modell von oben nichts davon, bekommt die Hülle eine minimale Rücken-Marke in derselben Farbquelle — keine neue Farbe erfinden.
4. **Zwölf Plätze je Rinne, KEINE Lagen mehr**: `STORE_PLACES` = `STORE_CAPACITY` = 12, Stapeln (`_store_seat`-Oberlage, `top_stored_pack`, `stored_pack_at` mit Lage) stirbt. Platz 0 liegt LINKS (am Tray), neue Pakete reihen sich rechts an.
5. **In der Rinne rückt nach**: wird ein Paket geöffnet, gleiten die rechten nach links (Rinnen-Grammatik). Der Platz ist damit der Index in `stored_packs(lane)` — `store_slot` stirbt, wenn nichts anderes ihn braucht (Agent prüft `card_pack.gd`/`dice_pack.gd`/`module_pack.gd`, `test_module_pack`, `test_pack_choice`). Gleiten über das vorhandene `glide_to` im EINEN Schreiber `_sync_store_bodies`.
6. **HOVER hebt das Paket aus der Rinne** (präsentiert = Hebebühne, senkrecht nach oben), so weit, daß seine Fläche über dem Filz steht und liest — nur wenn geöffnet werden darf, wie heute. Klick öffnet wie heute. Treffer-Test: das Rechteck des Rückens, quer erweitert auf die Rinnenbreite, damit dünne Pakete treffbar bleiben.
7. **Kopf je Rinne** bleibt (Name, n/12, „öffnen nach der Runde"), links vor der Rinne oder darüber — der Agent wählt, was in 570 px drei Rinnen ruhig unterbringt.
8. **Breite folgt dem Inhalt**: 12 × (dickstes Paket + Fuge) + Rand. Das Lager wird also deutlich schmaler; rechts daneben bleibt Filz frei.
9. **Die ÖFFNUNGS-FLÄCHE bleibt UNVERÄNDERT** (der Spieler denkt darüber noch nach): sie mißt heute ihre rechte Kante am Lager — diese Kante wird auf ihren heutigen Wert festgeschrieben (Displayrand minus `PACK_AREA_EDGE`), ihre Oberkante bleibt eine Fuge unter dem Lager. `EXTRA_RIGHT` bleibt 414 px, damit sich nichts sonst bewegt. Gemessen muß die Fläche danach wieder 1480,4 × 754,9 px sein.
10. Flüge ins Lager (Kauf, Wett-Gewinn) landen auf ihrem Platz in der Rinne — der Körper richtet sich im Bogen auf (Endzustand zuerst: Platz und Pose stehen vor dem Flug). Die CHIPS-Station rahmt Tray ∪ Lager wie heute (wird von selbst enger).

## Was bleibt
`TableScreen.PIT_STORE_CARDS/DICE/MODULES` und `MAX_PITS` dürfen bleiben (drei Rinnen = drei Gruben ist der einfachste Weg) — oder eine Grube mit drei Rinnen-Böden, wenn das sauberer ist; Agent entscheidet, beide Shader mitziehen falls `MAX_PITS` sich ändert. `ChipTrayView.set_pocket_limit` bleibt (die Tasche endet vor der Lager-Grube).

## Rückbau
Lagen-Logik (siehe 4), `PackStoreView.COLUMNS/ROWS/LAYERS`, Grundriß-Rechnung für liegende Pakete im Lager, veraltete Tests umschreiben statt auskommentieren.

## Nicht anfassen
Die offenen Debug-Änderungen im Arbeitsbaum (`GameRun.debug_fill_store`, `HubView.debug_packs_requested`, `scene_root._on_debug_packs_pressed` — „Debug: Lager voll") bleiben erhalten; `debug_fill_store` an die neue Kapazität anpassen, falls nötig. Sie sind das Werkzeug für die Sichtprobe mit 12 Paketen je Rinne.

## Docs
Root-`CLAUDE.md` (Abschnitt *Das PAKET-LAGER und die ÖFFNUNGS-FLÄCHE — das Layout rechts*: Lager-Teil neu, gemessene Maße), `scripts/ui/CLAUDE.md`, `scripts/table/CLAUDE.md`, `scripts/core/CLAUDE.md` (Kapazität/Plätze), Kurz-Nachtrag in `docs/plan_paket_lager.md` („Lager abgelöst durch plan_lager_rinnen.md").

## Umsetzung (2026-11-14)
- **Fassung** `PackStoreView`: drei Rinnen übereinander (Karten, Würfel, Module), Kopf je Rinne DARÜBER (Name, n/12, „öffnen nach der Runde“), `PLACES` 12, gemeldet wird der Rücken des dicksten Pakets (`spine_px`), daraus Teilung (`pitch_px` = Dicke + 12 % Fuge), Rand und Kopf. Ein Platz ist ein Streifen der Teilung über die volle Rinnenbreite (`slot_rect`/`slot_at`). EINE Grube je Rinne (drei `PackPitView`, `PIT_STORE_*` 33–35 unverändert, `MAX_PITS` unverändert).
- **Kern** `GameRun`: `STORE_PLACES`, `store_slot` (in `CardPack`/`DicePack`/`ModulePack`), `_free_store_slot` und `top_stored_pack` gestorben; `stored_pack_at(lane, index)` liest den Index. Geöffnet rückt nach, ein neues Paket reiht sich hinten an. `debug_fill_store` brauchte keine Änderung.
- **Körper** `CardPackView`: `set_standing`/`stand_on` (Ursprung = Mitte des Rückens, Fläche nach Bild-rechts, liegend byteweise die alte Pose), im Flug ins Lager richtet sie sich auf, im Flug zur Öffnung legt sie sich hin. Der Grundriß rechnet immer liegend (`_pose_free`). Rücken-Marke `add_spine` (Sortenfarbe/Stufe, Schatulle innen die Güte) — gesetzt, weil der Rücken oben sonst nur Gehäuse zeigte. Die dem Betrachter zugewandte Längsseite trägt an der CHIPS-Station ohnehin Naht/Saum, Schließe (Güte) bzw. Stufen-Streifen.
- **Griff**: hebt senkrecht, bis das Paket ganz über dem Filz steht, und KIPPT dann seine Fläche zur Kamera (flach 0,12 Welt über dem Filz) — senkrecht allein liest die Fläche unter der 15°-Kamera nicht. 0,36 s.
- **Kein Überstand**: die Rinne ist so tief wie die lange Seite plus Luft (5,57 Welt), der Rücken steht 0,03 unter der Schnittkante; in der Sichtprobe liest die Rinne so voll und ruhig.
- **Öffnungs-Fläche**: `area_for` nimmt die rechte Kante nur noch aus `right_limit`; scene_root gibt die festgeschriebene Kante (`OPENING_RIGHT_INSET` 19,857 px vor dem Displayrand — die gemessene Kante des alten Lagers, nicht `PACK_AREA_EDGE`, das 1,1 px daneben läge).
- **Gemessen** (1280 × 720): Lager **808,6 × 570** Display-px (x 3719,6–4528,2, y 1304,8–1874,8; vorher 1354,6 breit), Rinne **796,5 × 159,0**, Rücken 58,1 × 134,8, Teilung 65,0, Kopf 27,0 px; Öffnungs-Fläche **1480,4 × 754,9** (x 3593,7–5074,1, y 1898,2–2653,1) — unverändert.
