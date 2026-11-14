# Plan: Paket-Lager und eigene Öffnungs-Fläche (2026-11-13)

Spieler-Wunsch: Ein Paket öffnet sich nicht mehr beim Kauf. Es wandert in ein LAGER, und geöffnet wird per Klick darauf, in einer eigenen Öffnungs-Fläche. Löst `docs/plan_paket_im_hub.md` ab (Hub-Seite fällt).

## Entscheidungen (Spieler)
1. **Würfeln beim Öffnen**: Größe und Güte stehen beim KAUF fest (Paket-Eigenschaft: Art, Größe, Güte-Stufe). Optionen, Wahlen, Glückswurf und Neu-mischen-Zustand entstehen erst beim ÖFFNEN (`pending_pack_choices` wird dort gebucht, mit dem Glück von dann).
2. **Kapazität**: 8 Karten-Pakete UND 8 Würfel-Pakete, je Art eigene Lane, zusammen 16. Ein voller Platz sperrt den Kauf dieser Art im Laden (Tooltip/Hinweis nennt es, kein Geld wird gebucht).
3. **Öffnen nur, wenn keine Runde läuft** (Phase SHOP/Zwischenzeit, genau dann, wenn Pool und Magazin bearbeitbar sind — dieselbe Frage wie `_pool_editable`, Agent prüft die Phasen). Das Regal bleibt immer sichtbar; in der Runde sind die Pakete gesperrt und grau (wie Magazin/Werkstatt), Klick tut nichts / zeigt Hinweis.
4. Kein Verkaufen/Zurückgeben (noch nicht).

## Layout (gemessen 2026-11-13, Display 124,8 × 84,8 Welt = 4680 × 3180 px, 37,5 px/Welt, 1280×720-Probe)
- Wett-Tresen x 77,2–87,6; Chip-Tray (`PIT_TRAY` 32) x 88,2–98,6, beide y 34,8–50,0.
- Pool/Werkstatt/Magazin enden bei x ≈ 103,6 (Magazin-Grube `PIT_MAGAZIN` x 77,9–103,5, y 71,2–81; Werkstatt y 66,8–70,9; Info-Fenster y 63,1).
- **LAGER-REGAL**: rechts vom Chip-Tray, x ≈ 99,2 bis Displayrand 124,8, y 34,8–50,0 (Höhe wie Tray). Zwei Lanes (Karten / Würfel) zu je 8 Plätzen. Passt der Grundriß von 8 Paketen je Lane nicht in ~25 Welt Breite, rollt/staffelt das Regal wie der Magazin-Tablett (Agent entscheidet nach Messung; Ziel: alle 16 gleichzeitig sichtbar, sonst Roll-Spalten wie Magazin). Neuer Pit-Slot (`PIT_STORE`, `MAX_PITS` ggf. 34 in Skript UND beiden Shadern anheben, wie beim Tray).
- **ÖFFNUNGS-FLÄCHE**: rechts vom Pool/Magazin, x ≈ 104,5 bis ~124,8 (≈20 breit), y ≈ 51 bis ~83 (Hochformat). Der Agent misst die endgültigen Maße (`hub_geo_probe`-Muster, Probe `lay_all.gd` im Scratchpad liefert alle Fenster-Rects), prüft ob die Kamera-Übersicht dorthin schaut, und kann das Display ein paar Einheiten verbreitern, falls 20 zu eng ist (nur wenn nötig, sonst nicht).
- `lineup_grid` wird flächenabhängig: bei Hochformat (schmal) z. B. 3 Spalten × bis 4 Reihen für 10 Würfel; Breite/Höhe der Fläche entscheiden, Tests für 1..10.

## Ablauf
- **Kauf** (`purchase_card_pack`/`purchase_dice_pack`): bucht Geld und legt das Paket ins Lager (`GameRun.stored_packs`, je Art Liste, Reihenfolge = Kaufreihenfolge). Kein `pending_pack_choices` mehr beim Kauf. Das Paket FLIEGT aus dem Laden ins Regal (Spieler-Zug → Körper-Bogen über dem Tisch, Endzustand zuerst, ein Schreiber je Körper-Ort).
- **Öffnen** (Klick auf ein Lager-Paket, nur wenn keine Runde läuft): `GameRun.open_stored_pack(uid)` nimmt es aus dem Lager und bucht die Choice (Optionen/Wahlen/Glück). Das Paket fliegt zur Öffnungs-Fläche, die Kamera fährt auf eine neue Station (wie `configure_chips_target`), MODAL wie bisher (`_pack_choice_modal`), die Show läuft wie heute (CaseShow, Reihe, Walze, Neu mischen, Bestätigen). Bestätigt: gewählte Würfel → `pending_dice` → ZWANG (Raster liegt direkt links daneben), Karten → `grant_pack` ins Magazin; Schatulle/Kassette sinkt per `PIT_CASE` oder analoger Hebebühne ein.
- Die Landefläche (unsichtbarer Boden + Wände auf `PACK_LAUNCH_LAYER`) wird für das neue Rechteck gebaut, sonst unverändert.
- Harter Weg bleibt `_settle_pack_openings` (Lauf-Wechsel, Titel, Lexikon): eine offene Öffnung bleibt in GameRun und öffnet beim Zurückkehren neu; Lager-Körper werden am EINEN Ort (`scene_root`) neu aufgestellt (`seat_hard`).
- Lauf-Wechsel/Neustart leert das Lager.

## Rückbau (wird mit dieser Welle gelöscht, nicht nur ungenutzt)
Hub-Seiten-Öffnung (`_show_pack_choice_page`, `_close_shop_page`, `HubView.queue_page` falls nur dafür), `ShopController.suspend()/reopen()`-Pfad und `_resume_shop`, `PACK_SHOP_SETTLE_FRAMES`, Hub-Landefläche/Hub-Maße (`hull_seat_px`, `lineup_area_px`-Hub-Teil), Kamera-Tilt-Lock am Hub für Öffnungen — soweit nur dafür gebraucht. Der Laden bleibt bei jedem Kauf unberührt. Veraltete Tests auf Hub-Seite/Suspend umschreiben statt auskommentieren.

## Nebenpunkte
- Klausel-Texte *Freie Hand* / *Glücksgriff* lesen sich wie Karten-Paket-Regeln: prüfen, ob sie zur neuen Zeit-Logik (Optionen erst beim Öffnen) noch stimmen, ggf. Texte glätten (Tests `test_deal_clause_text`).
- Gewinn-Pakete (Wett-Gewinn als Paket) und Geld-/Sonder-Pakete: wo ein Paket aus einer anderen Quelle als dem Laden kommt, geht es ebenfalls ins Lager — Agent prüft alle Aufrufer von `purchase_*pack*`/`pending_pack_choices`; ist das Lager voll, bei Gewinn-Quellen: Paket verfällt NICHT, sondern wird sofort in die Öffnung gezwungen wie bisher (dokumentieren).
- Docs: Root-`CLAUDE.md` (PAKET-AUSWAHL und Tisch-Layout), `scripts/ui/CLAUDE.md`, `scripts/table/CLAUDE.md`, `scripts/core/CLAUDE.md`, `docs/plan_paket_im_hub.md` mit Hinweis „abgelöst“, Obsidian-Seite 46 (`E:\Obsidian Vault\Games\Fumble\46 Würfel-Pakete - Größe, Güte und das Öffnen.md`).
- Tests: Lager-Zustand (Kauf, Kapazität 8/8, Öffnen, Phase-Sperre, Lauf-Reset), Regal-View, Öffnungs-Fläche in Display-Pixeln für 1..10 Würfel, Laden bleibt bei Kauf unverändert, Suite am Ende einmal, Boot headless.

## Umsetzung und Nachtrag (2026-11-13)
Umgesetzt wie oben, mit den Spieler-Änderungen nach der ersten Fassung:
- **Breite folgt dem Inhalt** ("die neuen Fenster so breit wie sie sein müssen"): die Anzeige ist dafür um `TableScreen.EXTRA_RIGHT` (960 px = 25,6 Welt) nach rechts verbreitert, `RESOLUTION` 5640 × 3180, Layout-Maß `LAYOUT_SIZE` bleibt 4680 × 3180; alles Bisherige behält Pixel und Weltort.
- **Lager bündig** mit Wett-Tresen und Chip-Tray (y 34,8–50,0, 570 px), beginnt hinter der Tasche des Chip-Trays: 1749 × 570 px, x 102,1–148,8. Zwei Gruben NEBENEINANDER (links Karten, rechts Würfel) zu je 863 × 515 px, 2 × 4 Pakete in voller Breite, keine Überlappung.
- **Öffnungs-Fläche** direkt unter dem Lager bis zur Oberkante der Werkstatt-Zeile (Info-Schirm): 1005 × 446 px, x 102,1–128,9, y 50,6–62,5. Breites Layout: linke Spalte mit Schatulle, Kopf, Energie und Knöpfen, rechts die Aufstellung (10 Würfel 5 × 2, Netz-Zelle 29,6 px; 4 Würfel 4 × 1 bei 37,9 px).
- **Flimmern**: zwei Ursachen. (1) Die Tasche hinter dem Wandschlitz des Chip-Trays lag unter der linken Lager-Grube und war durch sie zu sehen → das Lager beginnt hinter ihr (`ChipTrayView.pocket_end_z`). (2) Die rechte Wandtasche des Magazins ragte über den Displayrand, ihre Decke lag 0,01 unter dem Bodenfilz und flimmerte durch ihn → sie endet höchstens am Displayrand (`ShelfStackView.pocket_limit_z`).
- Kamera: die Öffnung ist ein temporärer Rahmen (wie das Raster), das Lager liegt in der Station CHIPS (Tray + Lager).

### Zweiter Nachtrag (2026-11-13, Spieler-Änderungen)
- **Gruben zwei Pakete breit**, je 2 × 2 sichtbare Plätze; ab dem fünften Paket einer Art liegt eine zweite LAGE darauf (Paket 5 auf Platz 1 … 8 auf 4). Jedes Paket behält seinen Platz (`store_slot`) bis zum Öffnen; Klick und Hover treffen das oberste eines Stapels.
- **Fuge Tray ⇄ Lager** wie Tresen ⇄ Tray: die Tray-Tasche hinter dem Wandschlitz endet jetzt vor der ersten Lager-Grube (`ChipTrayView.set_pocket_limit`), statt dass das Lager ausweicht.
- Lager 930 × 570 px (x 99,2–124,0) paßt in die alte Anzeige; nur die Öffnungs-Fläche (1005 × 446 px, x 99,2–126,0) braucht mehr: `EXTRA_RIGHT` ist auf das Minimum 66 px (1,76 Welt) zurückgenommen, `RESOLUTION` 4746 × 3180.

### Dritter Nachtrag (2026-11-13, Spieler-Änderungen)
- **Drei Reihen**: je Grube 2 × 3 sichtbare Plätze, Kapazität 12 je Art (`STORE_CAPACITY` 12, `STORE_PLACES` 6, zwei Lagen); gestapelt wird ab dem siebten Paket (7 auf Platz 1 … 12 auf 6). Köpfe „x/12“.
- **Rand knapp**: `EDGE_SHARE` 0,14 → 0,09; Lager 903 × 570 px (x 99,2–123,3), Gruben je 439 × 515 px. Öffnungs-Fläche unverändert (1005 × 446 px direkt darunter), `EXTRA_RIGHT` bleibt 66 px — die Breite stellt die Öffnung für zehn Würfel, nicht das Lager.
- **Flimmern der Kassette**: Neon-Saum bündig mit den Gehäuseseiten, Stahlband (Normal) und Goldecken (Riesig) mit derselben Oberkante wie der Saum — beides z-fighting. Saum steht jetzt um `RIM_PROUD` vor, Band endet im Saum und darunter, Ecken überragen Saum und Naht. Gilt für jede Kassette, im Lager wie bei der Öffnung.

## Nachtrag (2026-11-14)
Das Lager aus drei Gruben zu 2 × 3 liegenden Plätzen mit zweiter Lage ist abgelöst durch `docs/plan_lager_rinnen.md`: drei Rinnen übereinander, die Pakete stehen hochkant, zwölf Plätze je Rinne, geöffnet rückt nach.
