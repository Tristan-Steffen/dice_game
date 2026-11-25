# Werkstatt Layout D — Info-Band über der Walze, acht Scheiben, ORIGINAL + UPGRADES

Spieler-Entscheid 2026-11-25. Löst Layout C (`plan_werkstatt_layout_c.md`) in diesen Punkten ab.

## Ziel

1. Der INFO-SCHIRM verläßt die Ecke rechts neben der Walze und wird ein dünnes, langes
   **INFO-BAND** zwischen Pool-Reihe/Gleichung und Walze — mittig zu allem, was der Zeiger trifft.
2. Kein Würfelnetz mehr im Info-Schirm: der überfahrene Vorrats-Würfel zeigt sich in der
   **Die-View des Podests** (ORIGINAL), der einen Würfel-Ansicht der Werkstatt.
3. Die Walze hat **ACHT** Scheiben.
4. Die Gleichung heißt **ORIGINAL + UPGRADES** — ORIGINAL (Podest) steht direkt am Pool,
   UPGRADES rechts daneben. **ERGEBNIS ist gestorben**: der „+“-Koppler ist ein UMSCHALTER,
   der die Die-View des Podests zwischen ORIGINAL und ERGEBNIS wechselt.
5. Dazu die Lesbarkeits-Punkte: feste Spalten im Band, Ruhe-Hinweis „nächster Schritt“,
   größere Schilder, ruhigere Hauben, ORIGINAL bleibt während einer Paket-Öffnung stehen.

## Layout (alles in `WorkshopView.drum_layout`, Display-Pixel)

Reihenfolge von oben nach unten, linksbündig mit dem Pool:

```
POOL | Fuge | PODEST (Platte über Die-View = ORIGINAL) | „+“ | UPGRADES | PRÄGEN
            |                                          Schale (über „+“/UPGRADES, oben bündig)
----- Naht -----
INFO-BAND (so breit wie das Magazin)
----- Stich-Band (kurze Leiterbahn-Stiche) -----
Nummern 1–8
GRABEN mit 8 Scheiben
----- Fuge -----
MAGAZIN (vier Trays, unverändert)
```

- **Gleichung**: `podium` beginnt bei `pool.end.x + gap` (dort, wo bisher UPGRADES stand),
  danach EIN Zeichen-Feld `signs[0]` („+“, der Umschalter), danach `upgrades`. Die Schlüssel
  `result` und das zweite Zeichen-Feld fallen ersatzlos. `equation` = Podest bis PRÄGEN.
- **PRÄGEN** (`stamp`): rechts neben UPGRADES, ein Zeichen-Feld Abstand, senkrecht mittig zur
  Netz-Zeile — es steht, wo bisher „=“ stand, und liest als „dann prägen“.
- **Schale** (`scene_root._fach_spot_px`): eine Fuge rechts neben der Podest-PLATTE, oben
  bündig mit dem Pool (über dem „+“-Feld / UPGRADES).
- **INFO-BAND** (`info`): x = Pool-Linkskante … Magazin-Rechtskante, y = eine Naht unter der
  Pool-Reihe. Höhe: so hoch, wie der Platz hergibt, Ziel ~17 u (zwei Zeilen), Minimum eine
  Zeile. Das Magazin darf dafür nicht unter die Hub-Unterkante rutschen
  (`_place_workshop_strip` warnt): zuerst die Fuge Walze–Magazin halbieren, dann das Band
  niedriger machen. Maße MESSEN und im Bericht nennen.
- **Leiterbahnen**: die Bahnen der Scheiben tauchen UNTER das Band. Sichtbar bleiben zwei
  Stücke: unten je Scheibe ein gerader Stich von der Grabenkante/Nummer in die Unterkante des
  Bandes (mit Durchkontaktierung an der Bandkante), oben das Bündel von der Oberkante des
  Bandes in die Unterkante von UPGRADES. Die waagerechte Verteilung liegt verdeckt unter dem
  Band — `trace_paths` wird entsprechend vereinfacht (Stiche unten, Bündel oben), Farb-Regel
  unverändert (leer farblos, belegt Kartenfarbe). `trace_band` = das Stich-Band.
- **Walze**: `DRUM_SLICES` 8, `DrumView.SLICES` 8, Nummern 1–8, linksbündig, Scheiben-Maß
  unverändert (EINE Größe je Ding). Rechts bleibt Filz bis zur Magazin-Kante.
- `bounds` (das Fenster) = Info-Band ∪ Nummern ∪ Graben ∪ Magazin.

## Regeln

### Acht Scheiben (core/)
`GameRun.SERIES_SLOT_CAP` 8; Start bleibt 2; Preis bleibt „bisherige + 1“ (3 … 8 ⚡).
Alles, was „6“ als Scheibenzahl kennt, zieht mit: `StorageBody` (acht Energiezellen, oben
4-3-2-1, unten 5-6-7-8, Füllstand „n/8“), `TRACE_PORTS`, `ACTION_WIDEST` („Verdichten 8/8“),
`storage_cells_px`, die Energiezellen-Körper und Nummern in `DieViewDress`, Licht-Netz/Strom.

### Der UMSCHALTER (ui/)
- `WorkshopView.result_shown: bool` (Standard WAHR), Signal `result_toggled(on)`, ein
  unsichtbarer Knopf auf `signs[0]` schaltet um. Der Zustand überlebt Neuaufbau und Wahl,
  der Laufwechsel setzt ihn auf WAHR.
- Die Die-View des Podests zeigt bei AN, was bisher ERGEBNIS zeigte (geparktes `_net`:
  Live-Vorschau mit Deltas, tickend beim Prägen, stehendes Ergebnis; beim Verdichten die
  Karte, die herauskäme), bei AUS, was bisher ORIGINAL zeigte (`_fill_podium`). Beide Netze
  liegen am selben Platz, sichtbar ist genau eines. Gibt es nichts zu rechnen (kein Ziel,
  keine Karte), steht in beiden Stellungen dasselbe schlichte Netz bzw. leere Kreuz.
- Das Stahlschild der Die-View nennt den Zustand: „ORIGINAL“ / „ERGEBNIS“ / „VORSCHAU“.
- Besitzer-Zeile im Band: „Original · Name“ / „Ergebnis · Name“ / „Vorschau · Name“.
- `result_net_rect`, `ResultScreen`, `_result_host`, `_result_view` sterben; `_net_host`
  (Parkplatz) liegt im Podest-Schirm.

### HOVER ist VORSCHAU (ui/ + scene_root)
- `WorkshopView.hover_die` (gesetzt je Bild von scene_root aus dem Pool-Sitz unter dem
  Zeiger; null = keiner). Solange gesetzt und keine Zeremonie läuft, zeigt die Die-View
  DIESEN Würfel statt des gewählten — bei Umschalter AN samt Vorschau der gesteckten Serie
  auf ihm (`run.resolve_series(_series, hover_die)`), bei AUS schlicht.
- Kenntlich: Schild „VORSCHAU“, cyan Saum um die Die-View, Abtastring und OBEN-MARKE des
  Podest-Körpers schweigen derweil. Nur der WECHSEL baut neu.
- Dieselbe Quelle trägt den ANGEHEFTETEN Vorrats-Würfel einer Würfel-Öffnung und den
  wartenden NEUZUGANG des ZWANGS (bisher `WorkshopInfoView.set_net`): Reihenfolge
  überfahren → angeheftet → wartender Neuzugang → gewählter.
- Zell-Hinweise der Die-View (`net_hint_at`) gelten für den gezeigten Würfel.
- `WorkshopInfoView.set_net` und das Netz im Info-Schirm sterben.

### ORIGINAL bleibt während der Paket-Öffnung stehen
- Die ÖFFNUNGS-ZONE beginnt am „+“-Feld (`signs[0].position.x`), nicht mehr an der
  Gleichung. Podest-Platte, Kammer, Die-View und ihr Schild sind KEINE Mitfahrer mehr und
  bleiben sichtbar und bedienbar (Hover/Zell-Hinweise). `EQUATION_NODES` verliert sie.
- Der gewählte Würfel fliegt wie bisher heim, solange die Zone gebraucht wird (die Pool-Sitze
  müssen für die Zuordnung alle stehen); die Die-View zeigt derweil überfahren/angeheftet.
- Breite: die Zone samt Wurfplatz des Glückswürfels muß vor dem Displayrand (x 5094) enden.
  `PackChoiceView.panel_width_for` bekommt dafür eine Obergrenze; reicht sie nicht, schrumpft
  die Netz-Zelle der Kacheln, nie der Würfel. Öffnungs-Rahmen der Kamera neu rechnen
  (Würfel-Paket: Pool ∪ Podest ∪ Zone ∪ Info-Band ∪ Wurfplatz).
- ZWANG-Rahmen: Pool-Loch ∪ Schale ∪ Podest (statt Info-Schirm).

### Das INFO-BAND (ui/, `WorkshopInfoView`)
- Feste SPALTEN in EINER Fassung: links WAS (Name, darunter Sorte·Größe bzw. Besitzer in
  seiner Farbe), Mitte WIRKUNG (bis zwei Zeilen, Textbreite gedeckelt — keine 1800-px-Zeile),
  rechts WAS GEHT (die Geste am Ding, gedämpft, z. B. „Klick: zurück ins Magazin · Zug:
  umsortieren“).
- Würfel sprechen über `DieInfoBand` in der Fassung `LINE` (wie in der Grube).
- `set_info(title, sub, sub_tint, body, action := "")` bleibt der eine idempotente Schreiber.
- Gesten-Quellen (scene_root `_write_workshop_info` reicht sie durch): Karte im Magazin,
  Karte auf der Walze, leere Scheibe, gesperrte Scheibe (nächste: „Klick: freischalten · n ⚡“),
  Vorrats-Würfel, Podest-Würfel, Umschalter, PRÄGEN (bei Sperre der Grund aus `stamp_blocker`).
- RUHE = der NÄCHSTE SCHRITT, nie leer (`idle_info`): kein Würfel und keine Karte → „Würfel
  im Vorrat antippen“; Würfel ohne Karte → „Karte aus dem Magazin auf die Walze legen“;
  Karte ohne Würfel → „Würfel wählen“; beides → „Prägen bereit“; Prägung verbraucht →
  „Geprägt — die nächste Prägung gibt es in der nächsten Runde“; Rohling → der bestehende
  Verdichten-Text. Titel dabei „Nächster Schritt“.

### Körper (table/, gestellt von scene_root)
- `DieViewDress`: ERGEBNIS-Chip, „=“-Koppler und die Schiene dorthin sterben; die
  Schilder werden deutlich größer (aus der Werkstatt-Weitsicht lesbar: mindestens ~1,6× der
  heutigen Schrift, MESSEN); das ORIGINAL-Schild wechselt seinen Text; der „+“-Koppler zeigt
  den Umschalter (AN = leuchtend, AUS = dunkel) und hebt sich unter dem Zeiger.
- Schutzschalter PRÄGEN zieht an den neuen Sitz.
- `DrumView`: acht Scheiben. HAUBEN: nur die NÄCHSTE gesperrte trägt Warnschraffur, Preis
  und „FREISCHALTEN“; alle weiteren sind eine ruhige dunkle Haube ohne Schraffur, „GESPERRT“
  klein und gedämpft.
- Deck: ruhige Felder (`set_deck_quiet_rects`) für das neue Band, kein Feld mehr für ERGEBNIS
  und den alten Info-Schirm; `bake_deck` läuft danach wie bisher.

## Was bleibt
Podest/Kammer/Brücke, Magazin, Prägen-Zeremonie (die Die-View tickt bei Umschalter AN),
Verdichtung, Bewegungs-Gesetz, EINE Größe je Ding, Paket-Auswahl-Regeln, Glas-Ansicht.

## Wellen
- **Welle 1 — Regel und Fenster**: core (8 Scheiben), `drum_layout`, Umschalter,
  Hover-Vorschau als Fenster-Logik, `StorageBody` 8, Leiterbahnen, `WorkshopInfoView` als Band,
  dazu so viel scene_root, daß das Spiel bootet und die Station richtig steht (Info-Fenster,
  Schale, PRÄGEN, Hover-Meldung, `_write_workshop_info` ohne Netz). Tests dazu.
- **Welle 2 — Körper und Zone**: `DieViewDress`, `DrumView` (8 + Hauben), Energiezellen,
  Öffnungs-Zone ab dem „+“-Feld samt Mitfahrern/Rahmen/Breite, ZWANG-Rahmen, Gesten-Spalte,
  Deck-Felder, Sichtproben, Doku (Wurzel-, ui/-, table/-, core/-CLAUDE.md).
