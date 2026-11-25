# Werkstatt Layout E — Upgrades am Walzen-Ende, Vorschau am Pool

Spieler-Entscheid 2026-11-25 (Wahl „B1“ aus mehreren Skizzen-Runden). Löst Layout D
(`plan_werkstatt_layout_d.md`) in Anordnung, Scheibenzahl und Info-Schirm ab. Was Layout D
an REGELN gebracht hat, bleibt: der Umschalter, die Hover-Vorschau als Idee, der Ruhe-Hinweis
„nächster Schritt“, die Gesten-Auskunft, die großen Schilder, die ruhigen Hauben.

## Warum
Das Info-Band von Layout D war dem Spieler zu dünn und zu lang, UPGRADES rechts vom Würfel
las gegen die Laufrichtung der Walze, und das Magazin soll tiefer sitzen.

## Layout (alles in `WorkshopView.drum_layout`, Display-Pixel)

```
POOL | VORSCHAU (Die-View) | PRÄGEN  Schale |            | PODEST: Platte/Kammer
     | INFO-SCHIRM (Block, unter Vorschau   |            |         über ORIGINAL
     |  und Prägen, bis zur Pool-Unterkante)|            |
-------------------------------------------------------- | „+“ (Umschalter, senkrecht)
Nummern 1–6                                              |
GRABEN mit 6 Scheiben  ───────────────────────────────►  | UPGRADES (am Walzen-Ende)
----- Fuge -----
MAGAZIN (vier Trays) — die GRUBEN bündig mit der HUD-Unterkante
```

- **Walze**: wieder SECHS Scheiben (`DRUM_SLICES` 6, `DrumView.SLICES` 6), linksbündig mit dem
  Pool, Scheiben-Maß unverändert.
- **UPGRADES** (`upgrades`): eine Naht rechts neben der rechten Grabenwand, senkrecht mittig
  zum Graben, Netz-Maß wie ORIGINAL (dieselbe Zelle). Der Strom läuft Walze → UPGRADES.
- **PODEST** (`podium`, `podium_stage`, `podium_net`, `chamber`): genau ÜBER UPGRADES
  (gleiche x-Kanten), oben bündig mit dem Pool, Platte über Die-View wie bisher. Die Die-View
  ist ORIGINAL bzw. ERGEBNIS (Umschalter).
- **„+“-Feld** (`signs[0]`): der Streifen zwischen ORIGINAL (oben) und UPGRADES (unten), so
  breit wie die Netze — der Umschalter liegt jetzt WAAGERECHT als breites Feld, mindestens
  ~60 px hoch. Dafür sitzt der Graben entsprechend tiefer als die Pool-Unterkante.
- **VORSCHAU** (`preview`, NEU): eine Die-View im Netz-Maß eine Fuge (`DRUM_SHELF_GAP`)
  rechts am Pool, oben bündig mit ihm.
- **PRÄGEN** (`stamp`): rechts neben der Vorschau, senkrecht mittig zu ihr.
- **Schale** (`scene_root._fach_spot_px`): rechts neben PRÄGEN, oben bündig mit dem Pool
  (NICHT unter der Vorschau — dieser Platz gehört dem Info-Schirm).
- **INFO-SCHIRM** (`info`): ein BLOCK unter Vorschau und PRÄGEN: x von der linken Kante der
  Vorschau bis eine Fuge vor dem Podest, y eine Naht unter der Vorschau bis zur
  Pool-Unterkante (erwartet ~670 × ~250 px). Kein Band mehr.
- **Leiterbahnen**: das Spur-/Stich-Band zwischen Pool und Walze und die 24 Einzelbahnen je
  Scheibe sterben (`trace_band`, `trace_paths`, `TRACE_PORTS`, `TRACE_STITCH_UNITS`,
  `INFO_BAND_UNITS`). Sichtbar bleiben zwei kurze vierspurige Busse: rechte Grabenwand →
  linke Kante von UPGRADES, und Oberkante UPGRADES → durch das „+“-Feld → Unterkante der
  Die-View des Podests. Farb-Regel der Spuren unverändert (leer farblos, eine Spur leuchtet,
  sobald ihre Sorte steckt).
- **Magazin**: rückt nach unten, bis die Unterkante der GRUBEN (`columns`) auf der
  Hub-/HUD-Unterkante liegt; Fassung und Lichtleisten hängen darunter (sie müssen über dem
  Displayrand y 3180 bleiben). `_place_workshop_strip` prüft künftig genau das (Gruben ≤
  Hub-Unterkante, Magazin ≤ Displayrand). Fuge Walze–Magazin wieder `DRUM_SHELF_GAP`, wenn
  der Platz reicht (Schacht des Magazins darf nicht unter den Graben reichen — der Boot
  warnt).
- `bounds` (Fenster) = Nummern ∪ Graben ∪ Magazin; Gleichung, Vorschau, Info liegen wie
  bisher die Gleichung außerhalb (`equation` umfaßt Vorschau … Podest/UPGRADES/Schale-Zeile
  sinngemäß; die Abnehmer prüfen).

## Regeln

### Sechs Scheiben (core/)
`GameRun.SERIES_SLOT_CAP` 6, Start 2, Preise 3/4/5/6. `StorageBody` wieder sechs Energiezellen,
Füllstand „n/6“, `ACTION_WIDEST` „Verdichten 6/6“; seine Anschlüsse kommen jetzt von LINKS
(Bus aus der Walze), der Abgang nach OBEN.

### Die VORSCHAU (ui/ + scene_root)
- Eine eigene Die-View am Pool. Sie zeigt `WorkshopView.hover_die` (überfahrener
  Vorrats-Würfel → angehefteter Würfel einer Würfel-Öffnung → wartender Neuzugang des
  ZWANGS); ohne einen das leere Kreuz. Bei Umschalter AN und gesteckten Karten zeigt sie die
  Wirkung der Serie auf DIESEM Würfel (wie bisher, ohne zu buchen), bei AUS schlicht.
- Die Die-View des PODESTS zeigt wieder NUR den gewählten Würfel (ORIGINAL/ERGEBNIS nach
  Umschalter); der Modus „VORSCHAU“ dort samt cyan Saum und dem Schweigen von Abtastring und
  Oben-Marke stirbt. `die_view_label()` kennt nur noch „ORIGINAL“/„ERGEBNIS“.
- Zell-Hinweise: `net_hint_at`/`net_hint_owner_at` antworten für BEIDE Die-Views
  („Vorschau · Name“ dort, „Original/Ergebnis · Name“ am Podest).
- Die Vorschau trägt das Schild „VORSCHAU“ im selben großen Grad und eine eigene Fassung
  (Chip mit Fenstern wie die anderen Netze der Gleichung, Körper in `DieViewDress`).

### Der Umschalter
Unverändert in der Regel (`result_shown`, `toggle_result()`, Standard AN), nur liegt sein
Feld jetzt zwischen ORIGINAL und UPGRADES und ist breit — der Koppler-Körper wird ein
deutlich sichtbarer, breiter Schalter (AN leuchtend, AUS dunkel, hebt sich unter dem Zeiger).

### Der INFO-SCHIRM (ui/, `WorkshopInfoView`)
Ein Block statt eines Bandes, weiter EIN idempotenter Schreiber
`set_info(title, sub, sub_tint, body, action)`: oben TITEL und daneben/darunter die
Unterzeile in ihrer Farbe, darunter die WIRKUNG mehrzeilig (so viele Zeilen, wie der Block
hergibt, Schrift so groß, wie sie ungeschnitten paßt), am Fuß die GESTE gedämpft. Würfel
sprechen über `DieInfoBand` in der Fassung `ROWS` (wie im Schwarzmarkt-Fuß). Ruhe = der
nächste Schritt. Kein Netz im Schirm.

### Die ÖFFNUNGS-ZONE
- Beginnt eine Fuge rechts neben der VORSCHAU und reicht wie bisher nach rechts (Breite der
  Würfel-Auswahl, samt Wurfplatz vor dem Displayrand); oben bündig mit dem Pool, so hoch wie
  er. Sie deckt PRÄGEN, Schale-Platz, den rechten Teil des Info-Schirms und das PODEST.
- Die VORSCHAU bleibt während einer Öffnung stehen und bedienbar (sie ist der Platz des
  überfahrenen/angehefteten Würfels). Der INFO-SCHIRM ist während einer Öffnung ganz fort
  (die Auswahl hat ihre eigene Auskunft). UPGRADES und der Umschalter liegen UNTER der Zone
  und bleiben stehen.
- Das PODEST fährt wieder MIT: Platte, Kammer, Die-View samt Schild, Puck und ein
  aufliegender Rohling sind Mitfahrer bzw. fort, die Dauer-Löcher von Kammer und Wanne sind
  während Fahrt und Auswahl zu (die Regel vor Layout D: `_chamber_shown()`, siehe
  `git show HEAD:scripts/scene_root.gd`). Der gewählte Würfel fliegt heim.
- Kamera: Würfel-Paket = Pool ∪ Vorschau ∪ Zone ∪ Wurfplatz; Karten-Paket = Zone ∪ Trays;
  ZWANG = Pool-Loch ∪ Schale ∪ Vorschau.

### Körper (table/, gestellt von scene_root)
- `DieViewDress`: Fassung und Schild der VORSCHAU (neu, das Vorbild ist der in Layout D
  gelöschte ERGEBNIS-Chip: `git show HEAD:scripts/table/die_view_dress.gd`, `_build_result`);
  UPGRADES-Chip am Walzen-Ende mit Anschluß von links; breiter Umschalter-Koppler; Schienen/
  Busse nach dem neuen Verlauf; Schutzschalter PRÄGEN am neuen Sitz.
- `DrumView`: sechs Scheiben; die Hauben-Regel von Layout D bleibt.
- Energiezellen: sechs.
- Deck: ruhige Felder für Vorschau, Info-Schirm, Podest, UPGRADES.

## Was bleibt
Kammer/Brücke/Prägen-Zeremonie (der Strom endet am Walzen-Ende — dort steht jetzt UPGRADES,
das Podest direkt darüber), Verdichtung, Magazin-Mechanik, Paket-Auswahl-Regeln,
Glas-Ansicht, Bewegungs-Gesetz, EINE Größe je Ding.

## Wellen
- **Welle 1 — Regel und Fenster**: core (6), `drum_layout`, Vorschau-Die-View als
  Fenster-Logik, Podest-Die-View ohne Vorschau-Modus, `StorageBody`/Busse, `WorkshopInfoView`
  als Block, Magazin-Lage, dazu so viel scene_root, daß das Spiel bootet und die Station
  richtig steht. Tests.
- **Welle 2 — Körper und Zone**: `DieViewDress` (Vorschau-Chip, Koppler, Busse), Öffnungs-Zone
  ab der Vorschau samt Mitfahrern/Kammer/Rahmen, ZWANG-Rahmen, Deck-Felder, Sichtproben, Doku.
