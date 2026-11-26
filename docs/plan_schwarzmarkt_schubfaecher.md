# Plan: SCHWARZMARKT als SCHUBFÄCHER auf dem Grundriß der Automaten (2026-11-26)

Spieler-Wahl „C · Schubfächer“ aus drei Blender-Entwürfen
(`tools/blender_secret_shop_variants.py` `build_c`, Bilder
`E:/Generated Images/Fumble/schwarzmarkt_entwurf_2026-11-26/` — `c_schraeg.png`, `vergleich.png`).
Maßgeblich sind Maße, Teile und Zustände des Entwurfs.

## Ziel

1. Der Schwarzmarkt verläßt seine Tasche und steht auf dem Rechteck, das heute die
   Fumble-Automaten tragen (`slots_rect` in `scene_root._setup_table_screen`).
2. Er ist ein BAUTEIL: ein flaches Lack-Gehäuse hinten (Bild-oben), aus dem drei gleiche
   SCHUBFÄCHER zum Spieler (Bild-unten) ausfahren. Das 2D-Fenster malt nichts mehr.
3. Die Automaten verlassen den Tisch. Ihr Code bleibt (einer wird später Einschub eines
   wechselnden Bauteils), aber nichts von ihnen ist zu sehen oder zu bedienen.
4. Die alte Tasche des Schwarzmarkts ist freie Massefläche (Platz für das spätere Bauteil).

`GameRun` bleibt unberührt: Auslage, Preise, Kauf, Neu mischen — alles wie heute
(`secret_stock` hat 2 oder 3 Einträge: Charm, dann Sonderbestand + Wildcard ODER ein Projektor;
auf dem Wildcard-Platz kann eine Powerbank liegen).

## Das Bauteil

Grundriß im Entwurf 28,5 × 17,7 Welt (Breite gemessen, Höhe geschätzt — das echte `slots_rect`
MESSEN und die Teile uniform einpassen, die knappere Achse gewinnt, wie `LuckStationView.unit()`).
EINE Größe je Ding gilt: keine Ware wird skaliert; reicht ein Fach nicht, wächst die Zeile.

- **Gehäuse** (hinten, ~4,6 tief, ~1,3 hoch, vorn offen): schwarzer Lack, violette Zierleiste an
  der Vorderkante. Auf dem Dach je Fach ein NAMENS-SCHILD (Etikett-Display mit Stahl-Einfassung,
  `Label3D`): Name der Ware, gedimmt wenn zu teuer, „VERKAUFT“ rot, leerer Platz „— — —“.
  Darüber EIN breites INFO-DISPLAY über die Gehäusebreite (siehe *Auskunft*).
- **Schubfach** ×3, gleich groß (innen 8,2 × 7,4, Teilung 9,1): Stahlrand, violetter Leuchtboden
  (Punktraster + Saum; hell = bezahlbar, gedimmt = zu teuer), zwei Schienen auf dem Deck.
  Vorn die NASE: Lackblende mit Griff, Preis als Segment-/`Label3D`-Fenster samt Energie-Zeichen
  in `CasinoStyle.ENERGY`, darüber die Kauf-Leiste (violett hell / gedimmt / rot = verkauft).
- **Einfahren**: das Fach ist ein TELESKOP aus zwei Segmenten, zusammengeschoben paßt es ganz
  ins Gehäuse — kein Loch im Tisch, nichts ragt hinten heraus. Eingefahren sitzt die Nase
  bündig an der Gehäusefront.
- **Fußband**: links die Taste NEU MISCHEN (Körper, Preis daneben, gedimmt ohne Energie), rechts
  die Kontaktleiste, an der die Hub-Ader endet (`secret_hub_strip`, wird aus dem Rechteck
  ohnehin neu verlegt).
- **Bestückungsdruck** des Decks: „U6 NICHT BESTÜCKT“ statt „U6 AUTOMAT“.

Gebaut prozedural in GDScript wie `LuckStationBody`/`ChipTrayDress` (`StationParts`), kein glb.
Eigenlicht knapp unter der Bloom-Schwelle; nichts `mark_reflective`.

## Ware in den Fächern

Fach i trägt Angebot i der Auslage. Körper wie überall:
Charm = liegende Diskette (`_spawn_lying_disk`; der Holo-Projektor des alten Kartensitzes
entfällt), Karte = liegende `DataCellView`, Würfel = echter Würfel, Modul = `ComboPartBody`,
Projektor = leerer `CharmReaderView`, Powerbank = ein Körper im Bild der Rack-Batterie
(vorhandene Bauform nutzen, sonst schlicht aus `StationParts`). Beim Projektor-Angebot bleibt
das dritte Fach eingefahren.

## Abläufe (Endzustand zuerst, EIN Schreiber, EIN harter Weg)

- **Auslage / Neu mischen**: alle Fächer fahren mit der alten Ware ein, drinnen wird getauscht,
  sie fahren mit der neuen aus (ersetzt den Förderband-Schritt; Ton `shop_flip`).
- **Kauf von Lichtware** (Karte, Würfel, Modul): gebucht wird sofort wie heute; das Fach fährt
  MIT der Ware ein, dann startet das bestehende Licht (`secret_delivery_comet`,
  `part_delivery_comet` …) von der Gehäusefront. Das Fach bleibt zu.
- **Kauf von Trage-Ware** (Diskette, Projektor, Powerbank): der Körper hebt wie heute im
  Trage-Bogen ab (`charm_buying`/`projector_buying`/`powerbank_purchased` bleiben), danach
  fährt das leere Fach ein.
- **Verkauft** bleibt eingefahren bis zur nächsten Auslage.
- Laufwechsel und unsichtbares Fenster: harter Weg, nichts schuldet.
- Eine Maschine, die keiner sieht, spielt nicht: ungesehen wird hart gestellt.

## Bedienung

- Hover (überall, wo zu sehen): das Fach unter dem Zeiger hebt seine Ware leicht und füllt das
  INFO-DISPLAY.
- Kauf: Klick ins Fach (Schale oder Nase) — weiter NUR an der eigenen Station, aus der Ferne
  wird der Klick zum Zoom (die benannte Ausnahme bleibt, `_screen_forwards_pixel`).
- NEU MISCHEN: Klick auf die Taste, dieselbe Stations-Regel.
- Das Fenster (`SecretShopView`) bleibt der Ort der Logik und MELDET nur: `PARTS` in
  Stations-Einheiten, `part_rect`, `bay_rect(i)`, `nose_rect(i)`, `label_rect(i)`, `info_rect`,
  `reroll_rect`; Text-Regeln (Name, Preis, Zustand je Fach als reine Daten); unsichtbare Knöpfe
  über Fächern und Taste tragen den Klick. Es steht nicht mehr in den `window_*`-Uniformen;
  sein Feld ist ein ruhiges Feld des Decks.

## Auskunft

Das INFO-DISPLAY auf dem Gehäusedach ist ein kleiner eigener SubViewport (Muster
`DeckGlassView`) auf einer Fläche am Körper. Es zeigt den bisherigen INFO-FUSS (Titel, Wirkung,
beim Würfel `DieInfoBand` ROWS samt Netz), gespeist wie heute (`show_bay_annotation`,
`charm_foot_data`). In Ruhe ist es dunkel bis auf „SCHWARZMARKT“.
BEWUSST GESTRICHEN in dieser Welle (als OFFEN notieren): der Zell-Hover im Würfelnetz des Fußes
und die klickbaren Lexikon-Wörter darin. Die stehenden Schilder (`set_bay_plates`) sterben,
Name und Preis stehen am Körper.

## Was stirbt

`secret_vitrine` samt Vorhang-, Grad-, Tausch- und Schild-Maschine in `scene_root`
(`_sync_secret_vitrine`, `_place_secret_vitrine`, `_sync_secret_curtain`, `_swap_secret_stock`,
`_sync_secret_plates`, `_secret_recesses`, `_secret_charm_projector` …), die gemalte Seite von
`SecretShopView` (Kopf, Börse, Kartensitz, Bucht-Fassung, Schilder, Karten für Projektor und
Powerbank), `_secret_shop_rect`/`SECRET_SHOP_ASPECT`/`SECRET_SHOP_TOP_GAP`, die Löcher
`PIT_SECRET_*` (Plätze frei lassen, `MAX_PITS` bleibt). `VitrineView` selbst bleibt, wo der
Laden sie noch braucht.

## Automaten vom Tisch

`place_slot_bank_window` wird nicht mehr gerufen, das Fenster bleibt unsichtbar, keine
Klickzone, `slot_hub_strip` aus, Station `SLOTS` unerreichbar; alle Stellen in `scene_root`
gegen das fehlende Fenster sichern. `Charm.FEATURE_SLOT_MACHINE` steht in
`charm_offer_features()` auf false (kein Automaten-Charm im Angebot). `SlotBankView`,
`SlotMachine`, ihre Tests und Flug-Helfer bleiben liegen. Alles, was sonst noch Automaten
voraussetzt (Nebenwetten, Klauseln, Lexikon), finden und stillegen oder melden.

## Tests und Proben

- `test_secret_shop_view.gd` auf das meldende Fenster umschreiben (Rechtecke stabil, Fach ↔
  Angebot, Klick kauft, Projektor-Angebot, Powerbank, verkauft).
- Neu `test_secret_shop_body.gd`: Zustände je Fach, verkauft bleibt zu, Neu mischen fährt ein
  und aus, `settle_hard`, ein Schreiber, nichts ragt eingefahren aus dem Gehäuse.
- `test/unit/test_secret_shop.gd` (GameRun) bleibt unverändert grün.
- Sichtprobe `tools/godot_secret_shop_probe.gd` nach
  `E:/Generated Images/Fumble/schwarzmarkt_spiel_2026-11-26/`: Station mit voller Auslage,
  eins verkauft + eins zu teuer, Projektor-Angebot, Hover auf Würfel, Übersicht des Tisches.

## Doku

Kurz und im Hausstil nachziehen: Wurzel-`CLAUDE.md` (Projekt-Absatz, *Sichtbar heißt bedienbar*
bleibt), `scripts/ui/CLAUDE.md` (`SecretShopView`, Automaten), `scripts/table/CLAUDE.md`,
`scripts/core/CLAUDE.md` (*The shop is its own table window*, Automaten). Überholtes als
Geschichte markieren, gemessene Maße eintragen.
