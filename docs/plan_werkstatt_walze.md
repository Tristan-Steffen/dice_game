# Plan: Die Werkstatt V1 — senkrechte WALZE, KAMMER, Sorten-MAGAZIN (2026-11-18)

Spieler-Entscheide vom 2026-11-18 nach fünf Mockup-Runden. Das Blockmodell ist
`tools/blender_workshop_layouts.py` (Variante `v1`), die Bilder liegen in
`E:/Generated Images/Fumble/werkstatt_layouts_2026-11-18/` (`v1_station.png`, `v1_schraeg.png`).
Die Rechnung der Serie (`SeriesResolver`, `GameRun`) bleibt byteweise gleich — umgebaut wird,
wie man sie SIEHT und BEDIENT.

## Entscheide (Spieler)
- **Die WALZE steht SENKRECHT im Bild** (Achse Bild-oben → Bild-unten): sechs SCHEIBEN
  untereinander, Scheibe 1 OBEN. Jede Scheibe ist ein Vierkant um diese Achse; jede ihrer vier
  Seiten ist der Leser EINER Sorte. Die Karte LIEGT quer darauf (wie im Magazin, Netz nach oben)
  und ist die ganze Zeit ganz sichtbar.
- **VORHER über Scheibe 1, NACHHER unter Scheibe 6.** Beide Netze liegen quer wie überall.
- **Die PAKET-ÖFFNUNG liegt UNTER dem Würfel-Pool und ist genau so breit wie er** — für
  Würfel- UND Karten-Pakete (der Pool muß beim Öffnen sichtbar sein).
- **Das MAGAZIN steht rechts neben der Walze: VIER REIHEN, eine je SORTE** (Zahlen, Material,
  Runen, Sonderbestand — `Pack.SHELF_ORDER`), je Reihe ZWEI Karten sichtbar. Jede Reihe rollt
  für sich seitwärts. Die Sorten-Tasten, ▲▼ und das Stapeln der Tabletts in die Tiefe entfallen.
- **Der INFO-SCHIRM sitzt direkt über der Zahlen-Reihe** des Magazins.
- **Die KAMMER** (der Platz des Zielwürfels) liegt unter dem Magazin, neben NACHHER; der
  PRÄGEN-Knopf rechts neben ihr.
- **Nichts reicht tiefer als die Unterkante des Hubs.**

## Entscheide (Session, widerrufbar)
- Leere Scheibe steht AUF KANTE (45°); belegt liegt der Leser ihrer Sorte oben, bündig Y = 0.
- Die Scheibe dreht AN ORT (der Graben hat dafür Luft links und rechts der Karte).
- Schale (Ausgabefach) und RASTER-Taste bleiben rechts am Pool; die Walze beginnt rechts davon.
- Das leere Paket-Lager bleibt stehen (nicht Teil dieses Umbaus).

## Maße — gemessen am heutigen Stand (1280 × 720, Display-px, 37,5 px/Welt)
- Hub 1802,6 / 2002,3, 1068,75 × 1125 → **Unterkante 3127,3** (die Schranke).
- Pool-Reihe (`_pool_row_px`) 2916,4 / 1994,8, 585 × 487,5. Schale bei x 3553,9, 86,25 breit.
- Anzeige 5094 × 3180. Die liegende Karte 194,4 × 129,6.
- HEUTE endet das Magazin bei 3274,5 — unter Hub UND Anzeige (Warnung „Werkstatt-Streifen zu
  hoch“ beim Start). Der Umbau behebt das.

## Layout — gerechnet, in Welle 1 zu MESSEN
```
x 2916        3501  3554-3640   ~3665      ~3940  ~3965            ~4450
y 1995  [ POOL 585 ] [Schale]   [VORHER]          [ INFO-SCHIRM      ]
        [          ] [Raster]   [ 1     ]         [ Zahlen    □ □    ]
y 2482  [__________]            [ 2     ]         [ Material  □ □    ]
y 2507  [ PAKET-   ]            [ 3     ]         [ Runen     □ □    ]
        [ ÖFFNUNG  ]            [ 4     ]         [ Sonder    □ □    ]
        [ 585 breit]            [ 5     ]         [KAMMER] [PRÄGEN]
y 3127  [__________]            [ 6     ]
                                [NACHHER]   ← Unterkante ≤ 3127
```
- **Walzen-Spalte**: VORHER (Netz in Kartenzelle, ~130 hoch) + Naht + sechs Scheiben
  (Teilung = Kartenbreite 129,6 + Fuge, ~816) + Naht + NACHHER (~130) ≈ **1112 von 1132 px**.
  Das geht nur, wenn BEIDE Netze die Kartenzelle (`card_net_cell`, 35,09) benutzen — das
  größere Mindestmaß des Ziel-Netzes (42,5) fällt. Reicht es gemessen nicht, wird es GEMELDET,
  nicht still geschrumpft.
- **Graben**: Breite = Diagonale des Scheiben-Vierkants (Kartenlänge + Luft, × √2) plus Fuge,
  ein Dauer-Loch (ersetzt Turm-Bucht und Tischsektion, deren Plätze frei werden).
- **Magazin**: vier Reihen in der heutigen Lane-Teilung (~184), zwei Spalten in der heutigen
  Spalten-Teilung (~240); Oberkante bündig mit Scheibe 1.
- Die Nummern 1–6 stehen links am Graben (vom Fenster gemalt).

## Welle 1 — die Werkstatt selbst (dieser Auftrag)
Körper sind weiter die heutige `DataCellView`-Karte; die vier Datenträger kommen in Welle 3.
1. **Layout-Rechnung in `WorkshopView`** (ui/, reine Funktionen wie heute, Kette per Test
   festgehalten): `before_net_rect`, `slice_rect(i)` (Scheibe 1 oben), `drum_pit_rect`,
   `after_net_rect`, `shelf_row_rect(sort)`, `chamber_rect`, `stamp_seat_rect`, Info-Schirm über
   der Zahlen-Reihe; `bench_rect`/`hit_rects` decken alles. `scene_root._place_workshop_strip`
   setzt die Spalte rechts der Schale an die Pool-OBERKANTE. Abnahme: Unterkante ≤ Hub-Unterkante,
   die Start-Warnung ist fort.
2. **`DrumView`** (table/, ersetzt `TowerView`): sechs Scheiben, EIN idempotenter Schreiber
   `seat(packs)` — die Seite ist reine Funktion des Zustands (belegt → `Pack.shelf_rank`, leer →
   auf Kante), Endzustand zuerst, die Drehung ist nur die Fahrt dorthin (~0,25 s je Viertel).
   Leser-Seiten vorerst schlicht: Saum in der Sortenfarbe und Kürzel (`Pack.shelf_short`).
   Die Scheibe trägt KEINEN Klick; `slice_rect(i)` im Fenster trägt Klick, Zug und Zeiger
   (Tipp im Magazin → nächste freie Scheibe; Klick auf belegte Scheibe → heim; Zug → `move_slot`).
   ETAGEN-LEISTE, AUSWURF-BAHN, Stummel, `hover_slide` und die Turm-Tasche sterben.
3. **Karten fliegen ÜBER dem Tisch** (Magazin ⇄ Walze, Trage-Bogen): die Gruben-Ausnahme samt
   Durchbruch, `_pit_carry_peak` und dem Deckel fällt.
4. **Die KAMMER ist das Podest**: flache Grube mit Sockel und Puck, der Zielwürfel schwebt
   darüber (`CLAMP_HOVER`); KRONE, `podium_look_rect`, `crown_rect` sterben, `BENCH_TILT_TRIM`
   wird am neuen Ort neu gemessen. Der ROHLING liegt in derselben Kammer (eine Wiege statt des
   Würfels); `TableSectionView`, `net_glass_pane`, `PIT_SECTION` sterben. Kabel kommen in Welle 4.
5. **Netze**: VORHER zeigt den Zielwürfel, wie er IST (ohne Ziel das leere Kreuz); NACHHER die
   Vorschau mit Deltas bzw. das Ergebnis, ohne Ziel die SUMME DER SERIE, beim Verdichten die
   Karte, die herauskäme. Der Summen-Schirm entfällt.
6. **Das Sorten-MAGAZIN**: `ShelfStackView`/`PackDrawerView` zeigen alle vier Sorten ZUGLEICH
   als Reihen (zwei Spalten sichtbar, je Reihe eigener Roll-Stand und eigenes Zurückfedern,
   Überlauf-Glimmen je Reihe). `ShelfSelectorView`, `shelf_tray` und der Stapel in die Tiefe
   sterben; Lieferungen landen immer an ihrer Reihe (kein „verdecktes Tablett“ mehr).
7. **Die ÜBERTRAGUNG** (löst das DURCHLICHT ab; ui/ taktet, scene_root fährt, Buchung vor dem
   Licht, `held_faces()` bleibt): `slices_locked(time)` → je Karte
   `stream_passed(index, faces, values, glyph, time)` (Karte flammt, brennt aus, das
   `LightNetView` läuft von Scheibe zu Scheibe nach UNTEN) → `stream_struck(time)` (die heutigen
   Lichtfunken schlagen von NACHHER in den Würfel in der Kammer). Der Würfel verläßt die Kammer
   nicht; `die_raised`/`die_returned` und `_ride_die_over_tower` sterben.
8. **Kamera und Klick**: Werkstatt-Weit- und Nahsicht rahmen Pool ∪ Walze ∪ Magazin ∪ Kammer;
   die WORKSHOP-Klickzone folgt `hit_rects`. Die Werkstatt-Ausnahme in *Sichtbar heißt bedienbar*
   gilt weiter (Walze statt Etagen-Leiste).
9. **Die Paket-Öffnungen ziehen in DERSELBEN Welle unter den Pool** (gemessen 2026-11-18: an
   ihrem heutigen Ort überdecken beide Walze und Magazin — die Karten-Fläche x 3719,6–4260,0,
   die Würfel-Schiene x 3597,0–4236,6). Die Fläche ist das Rechteck unter der Pool-Reihe, GENAU
   so breit wie sie (585 px), von einer Naht unter dem Pool bis höchstens zur Hub-Unterkante.
   Würfel-Paket: die Schiene steht dort in zwei Spalten zu drei Reihen (`RAIL_ROWS` 3 bleibt),
   Fuß darunter; Podest-Würfel = Kammer-Würfel. Karten-Paket: `PackChoiceView` samt
   `PIT_OPENING`-Vertiefung an derselben Stelle (Aufstellung der liegenden Karten in zwei
   Spalten); das Magazin bleibt zum Blättern offen, der Zeiger über einer Option hebt nur noch
   ihre Sorten-Reihe hervor. Rahmungen (`_dice_opening_frame_px`, `_card_opening_frame_px`),
   Platz-Punkt und Flugziele folgen. Paßt eine Aufstellung gemessen nicht in 585 px, wird es
   gemeldet.
   **Info-Schirm**: er braucht 149,8 px, über der Zahlen-Reihe sind bündig mit Scheibe 1 nur
   129,6 — das MAGAZIN rückt darum um die fehlenden ~20 px tiefer (es löst sich von der
   Oberkante der Scheibe 1); Kammer und Prägen-Sitz rücken mit und bleiben über der Schranke.
10. Totes löschen, nicht stilllegen. Tests: Layout-Kette, `DrumView` (Seite je Sorte, leer auf
    Kante, idempotent), Sorten-Magazin, Takte der Übertragung; Doku in den Ordner-CLAUDE.md und
    der Wurzel (EIN Podest, Bewegungs-Gesetz, Magazin, Wörter Walze/Scheibe/Kammer/Übertragung).

## Welle 1 in PAKETEN (2026-11-18, nach zwei Anläufen: als ein Lauf zu groß)
Jedes Paket endet lauffähig, mit eigener Suite und Boot; eines nach dem anderen.
- **A** — Punkte 1–3: Fenster-Layout, Platzierung in scene_root, `DrumView` statt `TowerView`,
  Klick/Zug über `slice_rect`, Trage-Bögen über dem Tisch. Stand: `drum_layout` (ui/) und
  `DrumView` (table/) samt Tests liegen schon vor, nichts ist eingebunden. In diesem
  Zwischenstand dürfen die Paket-Öffnungen noch über der Walze liegen (Paket E räumt das).
- **B** — Punkte 4–5: Kammer als Podest samt Rohling, Netze VORHER/NACHHER.
- **C** — Punkt 6: das Sorten-Magazin.
- **D** — Punkt 7: die Übertragung.
- **E** — Punkte 8–10: Öffnungen unter dem Pool, Kamera, Aufräumen, Doku.

**Paket E, gemessen**: die Fläche unter dem Pool ist 585 × 596,3 (y 2531,0–3127,3).
Die Würfel-Schiene wird dafür NIEDRIGER als der Pool (~424 px hoch, Netz-Zelle 26,2 → ~22,8;
Würfel bleiben gleich groß). Das 5er-Karten-Paket braucht drei Reihen (421,4 px), die heutige
Fläche läßt 333,2: der KOPF der Fläche schrumpft auf EINE Zeile (Name · Zähler · Energie);
reicht das gemessen nicht, wird es gemeldet.
Umgesetzt 2026-11-18: Schiene 585 × 424,5 (Fenster samt Fuß 514,8, Netz-Zelle 32,9), das 5er-Paket
steht in 421,4 von 434,4 px Aufstellung. Die frühere „Welle 2“ ist damit erledigt.

## Welle 3 — die vier DATENTRÄGER (Auftrag 2026-11-18; Welle 1 ist committet, 2a87fd0)
Jede Sorte ist ein EIGENER Träger (Spieler-Wahl, Entwurf `tools/blender_data_media_set.py`,
Bilder `E:/Generated Images/Fumble/datentraeger_final/`): Zahlen = LOCHKARTE (Faktor-Netz
dieselbe Karte in Violett), Material = KASSETTE, Runen = TONTAFEL, Sonderbestand =
HOLO-EMITTER (AUS im Magazin und in jeder Auslage, AN auf der Walze, in der Kammer und im Griff).
- **EINE Größe bleibt**: alle vier passen in den Umriß der liegenden Karte (1,62 × 1,08 im
  Blender-Maß, im Spiel × `CASSETTE_SCALE`); das Netz liegt auf jedem an DERSELBEN Stelle mit
  DERSELBEN Zelle. Keine Fassung (Magazin-Mulde, Scheibe, Paket-Fenster, Auslagen) ändert ihr Maß.
- **Assets**: ein Export-Skript baut je Träger EIN GLB mit der HÜLLE (ohne Netz-Inhalt, ohne
  Text) nach `assets/models/hardware/`; leuchtende Teile sind eigene benannte Meshes, damit
  Godot sie tönt. Dreiecke sparsam.
- **Körper**: `DataCellView` wählt die Hülle nach `Pack.shelf_rank`; Netz, ×n-Marke, Griff,
  Flug, Ausbrennen und alle heutigen Zustände bleiben EIN Pfad. Sortenfarbe, Größen-Leiter
  (`tier_tint`/`tier_energy`), Gold der Reparatur-Karte und Stahlblau des Rohlings lesen weiter.
- **Netz-Bild je Träger** (`StampNetOven`): Lochkarte = Wert plus so viele Löcher, Kassette =
  Material-Kachel, Tontafel = glasierte Runen-Kachel, Holo = Leuchtlinien — soweit ohne zweite
  Rechnung machbar; sonst bleibt die heutige Backung auf dem neuen Träger.
- **Leser-Seiten der Scheiben**: jede der vier Seiten bekommt die Wiege ihres Trägers
  (Leuchtbett, Deck mit Dornen, Steinwiege, Kontakt-Dock) statt Saum und Kürzel.
- **Leere Scheibe**: bleibt auf Kante (Spieler hat nicht widersprochen), aber ohne Kürzel auf
  dem Grat.

Umgesetzt 2026-11-18: `tools/blender_data_media_export.py` → `data_punch_card/cassette/
clay_tablet/holo_emitter.glb` (1.132 / 1.694 / 882 / 1.282 Dreiecke, Dicke 0,04 / 0,126 /
0,128 / 0,063 Roh-Maß), `DataCellView` mit Hülle je Sorte, Holo AN/AUS (`projecting`),
Netz-Kleid je Träger (`StampNetOven.dress`), Wiegen an den Scheiben-Enden. Sichtproben
`E:/Generated Images/Fumble/werkstatt_welle3_datentraeger/`.

## Welle 5 — Layout A: die Werkstatt wieder UNTER dem Pool (Spieler-Entscheid 2026-11-18)
Die senkrechte Walze rechts vom Pool hat im Spiel nicht getragen. Zielbild:
`E:/Generated Images/Fumble/werkstatt_layouts_2026-11-18/a_unten_station.png`
(`tools/blender_workshop_layouts.py`, Variante `a_unten`). Was oben zu V1 steht, gilt nur noch,
wo dieser Abschnitt nichts anderes sagt.
- **Unter dem Pool, linksbündig mit ihm**: Zeile 1 die WALZE, jetzt LIEGEND (Achse Bild-links →
  Bild-rechts, Scheibe 1 LINKS, sechs liegende Karten nebeneinander), an ihrem rechten Ende die
  KAMMER, rechts daneben der Prägen-Sitz. Zeile 2 das MAGAZIN.
- **Keine Die-View über oder unter den Scheiben.** Rechts neben dem Magazin, unter der Kammer,
  steht die GLEICHUNG aus drei Netzen: ORIGINAL + UPGRADES = ERGEBNIS (Zielwürfel, wie er ist ·
  Summe der Serie · Vorschau bzw. Ergebnis mit Deltas), mit gemaltem „+“ und „=“. Der
  INFO-SCHIRM steht in demselben Block über der Gleichung.
- **Das MAGAZIN in vier Sorten-SPALTEN** (Zahlen, Material, Runen, Sonderbestand von links),
  je Spalte zwei Karten untereinander sichtbar, jede Spalte rollt für sich SENKRECHT.
- **Das PODEST** (Paket 2): rechts von Pool und Schale, auf Pool-Höhe, mit EIGENER Die-View
  darunter. Ein im Pool getippter Würfel geht aufs Podest — nur zum ANSEHEN (drehen,
  Doppelklick-Inspektion), er ist damit noch KEIN Ziel. Mit der ERSTEN gesteckten Karte fliegt
  er in die KAMMER und ist Ziel (stecken schon Karten, fliegt er direkt aus dem Pool dorthin);
  wird die letzte Karte zurückgelegt oder ist geprägt, fliegt er aufs Podest zurück;
  Rechtsklick/derselbe Tipp schickt ihn in den Pool. Ohne Würfel bleibt Prägen grau.
  Der ROHLING geht wie bisher direkt in die Kammer; ein Podest-Würfel bleibt dann oben.
- **Die PAKET-ÖFFNUNG zieht zurück rechts neben das Podest**, Oberkante = Pool-Oberkante, so
  hoch wie der Pool: die Würfel-Schiene in ihrer alten Form, die Karten-Fläche an derselben
  Stelle (fünf liegende Karten in 3 + 2).
- **Höhe**: unter dem Pool sind 596,3 px (2531,0–3127,3). Walzen-Zeile (Graben = Diagonale des
  Scheiben-Vierkants) + Naht + Magazin (zwei Reihen) müssen hineinpassen — messen, melden.

**Paket 1 umgesetzt 2026-11-18** (gemessen 1280 × 720, u = 5,042): Graben x 2916,4–4207,2, y
2554,2–2757,6 (Nummern 23,2 darüber, ab der Naht 2531,0), Kammer x 4216,3–4422,3, Prägen bis x 4537,3,
Magazin x 2916,4–3920,3, y 2777,7–3106,7 (Spalten 213,8 × 320,4, Platz-Teilung 160,2), Info-Schirm
x 3940,4–4594,2, y 2777,7–2927,6, Gleichung (Netze 194,4 × 129,6) y 2977,1–3106,7 — unter dem Pool
bleiben 20,6 px, nichts geschrumpft. Podest-Platz 201,7 × 352,9 ab x 3660,3; Öffnungs-Fläche
646,6 × 487,5 ab x 3882,1; die Schiene ist 442,3 hoch (Fenster samt Fuß 536,2, unten bei 2531,0) —
so hoch wie der Pool reichte ihr Fuß bis y 2586 in die Walze. Sichtproben
`E:/Generated Images/Fumble/werkstatt_layout_a_paket1/`.

**Paket 2 umgesetzt 2026-11-18**: `WorkshopView` trennt `chosen_die()` (Podest oder Kammer) von
`target_die()` (Ziel, sobald eine Karte steckt), `podium_die()`, Signale `die_chosen` und
`target_changed`; scene_root führt EINEN Körper mit `_bench_spot`, Podest ⇄ Kammer per
`_ride_bench_between`. Podest-Platte 201,7 × 214,3 ab y 1994,8, Die-View 194,4 × 129,6 bei y
2218,1–2347,7; Anker-Versatz 0 | 47,8 Display-px (Weitsicht: der Würfel liest 0,4 | 1,1 px neben
der Plattenmitte). Walzen-Netzzelle weit 24,6 / nah 31,3 Viewport-px wie vorher — die Nahsicht
schließt das Podest nicht ein. Sichtproben `E:/Generated Images/Fumble/werkstatt_layout_a_paket2/`.

## Zurückgestellt
- **Die KABEL** in der Kammer (Spieler-Entscheid 2026-11-18: vorerst nicht). Die Lichtfunken
  bleiben die Zeremonie.

## Spiel-Ideen (nicht Teil der Wellen)
- Zwischenstand: Hover auf Scheibe i zeigt in NACHHER den Stand nach dieser Karte.
- Die ERDUNGSKLEMME neu: „Dieses Prägen lädt den Zielwürfel nicht auf“ (ihr Text ist tot).
