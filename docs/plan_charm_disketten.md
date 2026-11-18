# Plan: Charms als DISKETTEN in HOLO-LAUFWERKEN (2026-11-18)

Spieler-Wunsch: jeder Charm ist eine 3,5"-Diskette. Im Laden liegt sie als Ware, gekauft steckt sie
in einem von SECHS Laufwerken, die die sechs Charm-Plätze ersetzen; oben auf jedem Laufwerk
projiziert ein Projektor das Hologramm des Charms. Gewählt ist das TERMINAL-Layout
(`tools/blender_floppy_layouts.py`, Lauf `final`; Renders in `E:/Generated Images/Fumble/floppy_terminal/`).

## Entscheide (Spieler, 2026-11-18)
- **Layout TERMINAL**: schwarz lackierte Diskette, dunkelverchromter Schieber, schwarze Glasfront.
  OBEN (steckt im Laufwerk): Charm-Bild als Kachel, „LOAD <ID>.DSK“, schlanker Ladebalken.
  UNTEN (bleibt draußen): „> NAME“ in der Raritätsfarbe, die Wirkung in Bildschirm-Cyan, so groß
  wie das Feld erlaubt (kurze Texte werden größer), am Fuß das Raritätswort und vier LEDs
  (so viele leuchten wie die Stufe 1–4); ein dünner leuchtender Rahmen in der Raritätsfarbe.
- **Nur Schieber und Bild stecken**: `INSERT` = 0,56 der Diskettenlänge; der Text liegt IMMER vor
  dem Schlitz und ist im Spiel lesbar, während der Charm steckt.
- **Das Hologramm bleibt das heutige**: massives Modell mit Lichtkante (`charm_hologram.gdshader`,
  `apply_hologram`, Spot je Platz auf `MODEL_LIGHT_LAYER`, Schweben/Bob/Drehung, `flash_charm`).
  Der Cyan-Durchscheinlook der Blender-Renders wird NICHT gebaut (Retro, zu hell — gestorben 2026-09-09).
  Nur Emitter-Ring und Kegel wandern auf die Projektor-Linse des Laufwerks.
- **Das 2D-Charm-Dock (`CharmDockView`) stirbt** samt `test_charm_dock_view.gd`. Was es trug, zieht um:
  Bild + Name + Wirkung → die Diskette selbst; Dauer-Chips (Zähler) → das FRONT-DISPLAY des
  Laufwerks; Schlüsselwort-Klicks → ein schlanker Hover-Tip an der Diskette; Umsortieren → Diskette
  von Laufwerk zu Laufwerk ziehen; Verkaufen → AUSWURF-TASTE.
- **Der Laden verkauft körperliche Disketten**, der Schwarzmarkt ebenso; gekauft fliegt die
  Diskette zum ersten freien Laufwerk und gleitet hinein.
- **Verkaufen über die Auswurf-Taste**: Hover über ein belegtes Laufwerk zeigt den Preis auf seinem
  Front-Display, ein Klick auf die Taste verkauft.

## Maße — EINE Größe je Ding
Die Diskette hat EINE Größe: im Laden, im Flug, im Laufwerk. Sie wird als Konstante geführt
(Vorschlag `CharmDiskView.SIZE`) und an der Reihe bemessen: die Reihe hat `LINE_SPACING` 9 Welt;
ein Laufwerk ~8 Welt breit ⇒ Blender-Faktor ≈ 7,1 ⇒ Diskette ≈ **6,4 × 6,7 Welt**, Textfeld vor dem
Schlitz ≈ 2,7 Welt tief, Laufwerk ≈ 2,1 Welt hoch. Das Hologramm (Modellhöhe gemessen ≤ 4,01 Welt bei
`MODEL_SCALE` 4) schwebt über der Linse statt über dem Filz — `HOVER_HEIGHT` wächst um die Laufwerkshöhe.
**Wer eine Fassung baut, paßt SIE an**: reicht der Charm-Platz im Laden nicht für die liegende
Diskette (≈ 240 Display-px bei 37,5 px/Welt), wächst die Charm-Zeile, nie schrumpft die Diskette.
Die Reihe steht am hinteren Tischrand (`LINE_X` 31); der Schlitz zeigt zum Spieler (Bild-unten),
der Text liegt also dort, wo heute die Dock-Konsolen liegen.

**Lesbarkeit ist eine Abnahme-Messung**: bei 1280 × 720 an der Übersicht und an der CHARMS-Station
muß der Name ≥ 14 Bildschirm-px und die Wirkung ≥ 9 px Versalhöhe erreichen (Probe mit
`--quit-after`, off-screen). Schafft es der längste Text (Phönixfeder) nicht, wird das hier vermerkt
und dem Spieler gemeldet — nicht still die Diskette vergrößert.

## Assets (Blender → GLB)
- `tools/blender_floppy_export.py` baut aus `blender_floppy_layouts.py`/`blender_floppy_charm.py`:
  - `assets/models/charm_disk.glb` — NUR die Hülle (Gehäuse, Schieber, Fenster, Löcher, Nabe,
    Glasfront). KEIN Text, KEIN Bild, keine LEDs — die setzt Godot je Charm.
  - `assets/models/charm_reader.glb` — Gehäuse, Blende mit Schlitz, Auswurf-Taste, Projektor
    (Sockel, Topf, Linse, Ring, drei Spitzen), Lüftungsrillen. Die leuchtenden Teile sind EIGENE,
    benannte Meshes (`Lippe`, `Kopfsaum`, `Ring`, `Linse`, `Spitzen`, `Lampe`, `Display`), damit
    Godot sie in der Raritätsfarbe tönt bzw. an/aus schaltet, ohne das GLB anzufassen.
  - Ursprünge: Diskette = Mitte ihrer Unterseite; Laufwerk = Mitte unten, Schlitz nach −Z (Bild-unten
    nach dem Einbau), Linsenmitte als Empty `Linse`. Maßstab in Blender-Einheiten, skaliert wird in Godot.
  - Dreieckszahl prüfen (`tools/shrink_glb.py`), Bevel-Segmente sparsam.
- **Schrift**: Consolas ist eine Windows-Systemschrift und darf nicht mit. Mitgeliefert wird
  **Anonymous Pro Bold** (OFL, lag schon im Repo unter `addons/gut/fonts/`), kopiert nach
  `assets/fonts/AnonymousPro-Bold.ttf` samt `assets/fonts/OFL.txt`; kein Download. Der Blender-Export
  rendert ab dann mit derselben Schrift (`MONO` in `tools/blender_floppy_layouts.py`).

## Körper (table/)
- **`CharmDiskView`** (neu, `table/`): lädt `charm_disk.glb`, setzt je Charm
  - Glasfront-Inhalt als `Label3D` (Name, Wirkung, Raritätswort, `LOAD …`), Bild-Kachel als Quad
    mit dem Charm-Bild, Rahmen und LEDs als unshaded Quads/Meshes in `Charm.RARITY_COLORS`;
  - **Auto-Größe der Wirkung**: größte Schrift, bei der der umbrochene Text ins Feld paßt
    (`Font.get_multiline_string_size`), mit Deckel nach oben — dieselbe Regel wie `fit()` im
    Blender-Skript. Eine reine Funktion (testbar ohne Szene), z. B. `static func fit_size(text, width, height)`.
  - Das Charm-Bild: einmal je Charm-Id gerendert und als `ImageTexture` gecacht (`CharmThumb` mit
    `rotatable=false` rendert genau ein Bild) — keine dauernd laufenden SubViewports je Diskette.
  - `flash()` (Rahmen und Name pulsen wie heute die Pads), `set_lifted(bool)` für den Hover-Griff.
- **`CharmReaderView`** (neu, `table/`): lädt `charm_reader.glb`; `set_charm(charm_or_null)` tönt
  Lippe/Kopfsaum/Ring in der Rarität bzw. dunkel; `display_text(String)` schreibt das Front-Display
  (Zähler-Chip, beim Hover „VERKAUF $N“); `eject_rect_px()`/`disk_rect_px()` melden Trefferflächen;
  `lens_global_position()` ersetzt den Emitter-Mittelpunkt.
- **`CharmRowView`** wird zur Laufwerks-Reihe: sechs `CharmReaderView` auf den bisherigen Plätzen
  (`SPOT_COUNT` = `GameRun.CHARM_CAPACITY`), je eine eingesteckte `CharmDiskView`, das Hologramm über
  der Linse. Emitter-Torus und Kegel weichen dem Projektor (der Kegel bleibt, kurz und schwach, aus
  der Linse). `spot_global_position` → Linsenpunkt; `charm_index_at_screen_pos` trifft Laufwerk ODER
  Diskette. Bleibt der EINE idempotente Schreiber des Reihen-Zustands (`set_charms`).

## Abläufe (scene_root)
Bewegungs-Gesetz: was der SPIELER bewegt, fliegt ÜBER dem Tisch (Trage-Bogen); was der TISCH
einzieht, fährt per HEBEBÜHNE. Buchung vor dem Licht, Endzustand zuerst.
- **Kauf** (Laden + Schwarzmarkt): `GameRun` bucht wie heute (`charms_changed`), DANN fliegt die
  Laden-Diskette im Trage-Bogen zum Ziel-Laufwerk und gleitet in den Schlitz. Bis zur Landung zeigt das
  Laufwerk den Platz LEER (eine Fahrt-Marke wie `_exchange_hidden`) — ein Ding wird nie zweimal
  gezeigt. Steht die Reihe nicht im Bild, landet sie trotzdem (kein Warten auf die Kamera).
  Volle Reihe sperrt den Kauf wie heute (`charms_full`).
- **Verkauf**: Hover über ein belegtes Laufwerk → Display „VERKAUF $N“; Klick auf die Auswurf-Taste →
  `GameRun.sell_charm` bucht, die Diskette springt aus dem Schlitz und der Tisch zieht sie per
  Hebebühne ein (würfelgroße Sektion unter ihr, wie der Schluck); Geld als Licht vom Display zum Tray
  (`charm_money_comet` mit neuem Ursprung).
- **Umsortieren**: Zug an einer Diskette hebt sie aus dem Schlitz, sie folgt dem Zeiger über die
  Reihe, losgelassen über einem anderen Laufwerk tauschen beide im Trage-Bogen
  (`GameRun.move_charm` unverändert). Abbruch (Rechtsklick, Loslassen ins Leere) fliegt zurück.
- **Feuern**: `flash_charm(slot)` blitzt Hologramm, Ring, Linse UND die Diskette; das Pendel-Aufsteigen
  (`_show_pendulum_swing`) und alle Kometen, die heute an `charm_dock.pad_center(slot)` hängen, starten
  an EINEM neuen Anker `_charm_anchor_px(slot)` (Displaymitte des Laufwerks in Display-Pixeln).
- **Zähler**: `_update_charm_badges` schreibt seine Texte auf das Front-Display statt `set_badges`.
- **Schlüsselwörter**: der Hover über eine Diskette öffnet einen schlanken Tip (ui/, `LexikonText`)
  an ihrem gemeldeten Textfeld-Anker — klickbar wie heute, Klick öffnet das Lexikon. Der Tip faßt
  keinen Körper an; scene_root meldet ihm das Rechteck.
- **Harter Weg**: EIN Aufräum-Pfad (Laufwechsel, Laden schließt mitten im Flug, Verkauf während
  eines Flugs) setzt alle Disketten hart in ihre Laufwerke bzw. entfernt sie (`_settle_charm_disks_hard`).

## Laden (ui/ + scene_root)
- `ShopController` baut die Charm-Zeile nicht mehr aus `_build_charm_card`-Buttons mit Thumb, sondern
  MALT Plätze (Fassung, Preis-Chip, Gesperrt-Zustand) und MELDET je Platz ein Rect in Display-Pixeln;
  die Disketten selbst stellt scene_root (ui/ faßt nie Körper an) — dieselbe Grammatik wie die
  Paket-Fläche (`_write_shop_packs`). Name und Wirkung trägt die Diskette; Hover hebt sie (Griff) und
  zeigt den Schlüsselwort-Tip.
- Blättern, Leere Regale, Podest-Charm (garantierter Premium-Platz: stärkerer Rahmen) laufen weiter
  über `MenuSpread.charm_options`/`charm_bought`; der Warenumschlag fährt die Disketten mit der
  Hebebühne des Platzes wie die Pakete.
- `SecretShopView`: seine Charm-Ware wird ebenso Diskette; Kauf nur an der eigenen Station (bestehende
  Ausnahme in *Sichtbar heißt bedienbar* bleibt).

## Sichtbar heißt bedienbar
Hover (Tip, Display-Preis) antwortet überall, wo die Reihe steht. Verkaufen und Umsortieren gelten
dort, wo heute das Dock bedienbar ist (`_table_operable`); eine neue Stations-Ausnahme gibt es NICHT.

## Tests
- Neu `test/unit/test_charm_disk_view.gd`: `fit_size` (langer Text paßt ins Feld, kurzer wird größer,
  Deckel hält), LEDs je Rarität, Raritätsfarbe am Rahmen.
- Neu `test/integration/test_charm_reader_view.gd`: leer/belegt, Display-Text, Treffer der Auswurf-Taste.
- `test_charm_row_view.gd` angepaßt (Laufwerke statt Ringe, Hologramm-Material bleibt geteilt-sicher).
- `test_combo_and_counter_display.gd`: Zähler landen auf dem Display.
- `test_charm_dock_view.gd` entfällt mit dem Dock.
- Arbeitsschleife mit `-gselect`, die volle Suite EINMAL am Schluß, danach ein Boot (scene_root
  angefaßt); Sichtprobe der Lesbarkeit (siehe *Maße*).

## Doku
- `scripts/table/CLAUDE.md`: *Das CHARM-HOLOGRAMM* auf Laufwerk + Projektor umschreiben, neuer Abschnitt
  *Die CHARM-DISKETTE*; *Die VITRINE*: Charm-Zeile mit Disketten.
- Haupt-`CLAUDE.md`: Diskette in *EINE Größe je Ding*, Kauf-Flug/Auswurf in *Das Bewegungs-Gesetz*,
  UI-Wort vs. Code-Wort („Diskette“/`CharmDiskView`, „Laufwerk“/`CharmReaderView`).
- Totes restlos entfernen (Dock, Emitter-Torus, `_place_charm_dock`, `charm_dock`-Verdrahtung im
  `TableScreen`), nicht stilllegen.

## Reihenfolge (eine Feature-Welle, delegierbar)
1. Schrift + Export-Skript + beide GLBs; Import prüfen.
2. `CharmDiskView` + `CharmReaderView` + umgebaute `CharmRowView` (Dock steht noch) — Sichtprobe Lesbarkeit.
3. Dock-Umzug: Zähler, Tip, Auswurf/Verkauf, Umsortieren, Kometen-Anker; Dock löschen.
4. Laden + Schwarzmarkt mit körperlichen Disketten, Kauf-Flug.
5. Tests, Doku, volle Suite, Boot.

## Offene Punkte
- Die Gewöhnlich-Farbe ist fast weiß: Rahmen und Name lesen weiß statt farbig — eigene Farbe?
  (Spieler-Frage, nicht im Plan entschieden.)
- Lange Wirkungstexte (Phönixfeder) sind aus der Ferne die kleinsten; ggf. Texte kürzen.
- Kamera der CHARMS-Station neu rahmen: Laufwerke plus Hologramme sind höher als Ringe plus Modell.
- Licht-Deckel des Compatibility-Renderers: die Laufwerke leuchten unshaded, kein neues Licht je Platz.

## Umgesetzt (2026-11-18) — Abweichungen
- **Modelle in `assets/models/hardware/`** (`charm_disk.glb`, `charm_reader.glb`) statt `assets/models/`:
  dort liegen nur Charm-Modelle nach Id. Dreiecke: Diskette 1124, Laufwerk 5544.
- **Display, Auswurf-Taste und Lampe liegen OBEN auf dem Deckel** vorn statt an der Front: die
  15°-Tischkamera sieht die senkrechte Front kaum (gerechnet ~1 Bildschirm-px Displayhöhe).
- **Das Charm-Bild** ist eine geteilte `ViewportTexture` eines ruhenden `CharmThumb`-SubViewports je
  Charm-Id (einmal gerendert, `UPDATE_ONCE`), keine `ImageTexture`: kopflos liefert `get_image()`
  nichts. Kein Viewport je Diskette, keiner läuft dauernd.
- **`INSERT` ist das Blender-Maß 0,56** (= 0,6 der Diskettenlänge 0,94), nicht 0,56 der Länge.
- **Kein Griff-Hub im Laufwerk**: gehoben verdeckte die Diskette das Display mit „VERKAUF $N“; der
  Hover schreibt nur Display und Tip. Gehoben wird im Laden und am Schwarzmarkt-Sitz.
- **Der Laden-Preis steht AUF der Diskette** (`CharmDiskView.set_tag`, rechts neben dem Schieber):
  mit eigener Preiszeile lief die Seite um 51 px über. Das Charm-Band wächst um 29,6 px, die
  Auskunft unter den Paketen gibt sie her (`PLACE_INFO_UNITS` 4,6 → 3,2 u); die Seite steht weiter
  auf 1104 von 1104.
- **Kometen-Anker** `_charm_anchor_px` ist die Mitte der Disketten-VORDERKANTE, nicht die
  Displaymitte: das Display liegt auf dem Laufwerk, ein Licht auf der Anzeigefläche darunter wäre
  verdeckt; an der Vorderkante beginnt die Ader.
- **Der Einzug** einer verkauften Diskette läuft auf dem freien Löcher-Platz 31 (`PIT_CHARM`) — kein
  neuer `MAX_PITS`. Sie liegt dabei vor ihrem Laufwerk und damit über der Oberkante des
  Wertungs-Bildschirms (das Loch steht dort ~1,3 s).
- **Kamera CHARMS** rahmt jetzt die Reihe samt halber Hologrammhöhe (`configure_charms_target(target, half)`).
- **Disketten im Laden fahren beim Blättern NICHT mit der Hebebühne**; sie liegen hart (OFFEN).

## Lesbarkeit — gemessen 2026-11-18 (1280 × 720, Probe off-screen)
Schriftgrad (em) und Versalhöhe (Anonymous Pro: 0,637 em) in Bildschirm-px.
| | Name em / Versal | Wirkung Versalhöhe |
|---|---|---|
| Übersicht | 2,9–5,2 / 1,9–3,3 | 1,6 (Phönixfeder) – 3,2 |
| Station CHARMS | 9,6–20,8 / 6,1–13,2 | 5,2 (Phönixfeder) – 12,8 |
| Laden (Hub) | 9,9–13,4 / 6,3–8,5 | 4,9–8,2 |
Die Abnahme (Name ≥ 14 px, Wirkung ≥ 9 px Versalhöhe) schafft an der Station nur, wer kurz ist
(Standuhr, Fuchsschwanz, Sparschwein); an der Übersicht schafft sie keiner. Nicht vergrößert -
Spieler-Entscheid nötig (Texte kürzen, Station näher, oder lesbar nur an der Station).
Sichtproben: `E:/Generated Images/Fumble/floppy_integration/`.
