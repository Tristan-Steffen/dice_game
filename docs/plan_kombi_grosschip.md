# Plan: Der GROSSE Kombinations-Chip mit Modul-Sockeln

Stand 2026-11-21. Spieler-Entscheide dieser Runde (Sichtproben
`E:/Generated Images/Fumble/kombinationen_module_13_2026-11-21/r_rack_kombi_station.png` und
`_nah.png`; Modul-Blätter `kombinationen_module_5_2026-11-21/` und `_7_2026-11-21/`; Blockmodelle in
`tools/blender_combo_module_variants.py`: `chip_big`, `sock_kombi`, `MODULES`):

- Jede Kombination ist EIN breiter Chip: links die Anzeige, rechts drei SOCKEL im Deckel.
- Sockel = abgerundete Fassung genau in Plattengröße: dünner Stahlrand, schwarzer Boden, goldenes
  Kontaktfeld. Das Modul sitzt auf einer dunklen, abgerundeten PLATTE, die den Sockel ganz füllt.
- Über den Deckel läuft EINE Signalleitung durch alle drei Sockel.
- Layout: **3 Spalten × 4 Reihen bleiben** (Entscheid nach Messung, nicht das Rack aus den Bildern):
  die Chips wachsen nach LINKS in den freien Filz. Reihenhöhe, Schriftgröße und die Nachbarschaft
  (`ComboPartEffects.left_of/right_of/below_of`, `CLUSTER_COLUMNS` 3) bleiben unverändert.
- Regeln ändern sich NICHT: keine Reihenfolge-Wirkung, dieselben 26 Module, dieselben Phasen.

## Gemessen (Display-px, 1 Welt = 37,5 px)

Heute: Zelle 411,6 × 130,2, Fuge 25,2 × 16,8, Reihen auf die Grubenhöhe gespreizt (Teilung 146,6).
Zellfeld x 521,7–1806,9, y 1304,8–1874,8. Wurfgrube beginnt bei x 1801,5. Links von 521,7 ist
freier Filz bis zum Anzeigenrand (x 0). Darunter: Fumble-Automaten ab y 2002,3.

Neu: Zellbreite **505,7** (= 120,4 × `CLUSTER_SCALE` × `SUPERSAMPLE`; erst 558,6, am 2026-11-21 enger gestellt: Spalten-Fuge 16,8, `FIT_LENGTH` 0,95, der Chip blieb gleich groß), Höhe unverändert.
Zellfeld x ≈ 80,7–1806,9. Die rechte Kante bleibt, wo sie ist (Pin-Spitzen `PIT_SIDE_GAP` vor der
Grube). Chip-Gehäuse ≈ 10,9 × 2,84 Welt.

## Der Deckel (Chip-Raum, X längs, Z quer)

| Zone | Anteil der Gehäuselänge | Inhalt |
|---|---|---|
| Anzeige | links ~46 % (≈ 5,0 Welt) | Glas, Name, Wertung - Zeilenhöhen wie heute, die Wertung darf die ganze Zone nutzen |
| Sockel | rechts ~54 % (≈ 5,85 Welt) | drei Sockel, Teilung 1,95 Welt |

- **PLATTE** (die EINE Größe eines Moduls): `ComboPartBody.PLATE` = 1,5 (längs) × 1,9 (quer) Welt,
  Eckradius 0,3, Dicke 0,07. Modul-Hüllmaß auf der Platte: 1,4 × 1,3 × Höhe nach Seltenheit.
- **SOCKEL**: Stahlrand 0,06 um die Platte, Boden schwarz, Kontaktfeld 5 × 7 Gold-Pads ohne die
  vier Ecken, nur so groß wie die Platte. Kein Loch im Gehäuse nötig - er liegt auf dem Deckel.
- **LEITUNG**: ein leuchtendes Band auf halber Deckeltiefe vom Rand der Anzeige durch alle Sockel
  bis zum rechten Pin. Unter einer Platte läuft sie durch; über einem leeren Kontaktfeld liegt sie
  dünn obenauf.
- Frontband, Pins, Drossel („AUS“), Rampenlicht wie heute.

## Verhalten

1. **Abdeckung leerer Chips.** Hat ein Chip KEIN Modul, liegt über der Sockelzone eine Abdeckplatte
   im Gehäuseton mit dem Würfelbild der Kombination (`DiceScoring.EXAMPLE_DICE[key]`, als geprägte
   Würfelseiten mit Augen). Sie fährt auf (Endzustand zuerst, harter Weg vorhanden), sobald
   - der Chip ein Modul trägt, ODER
   - ein Einbau oder Umstecken läuft (`set_socket_beckon`, gezogenes Teil), ODER
   - der Zeiger an der KOMBINATIONEN-Station auf dem Chip liegt.
   Zu: Sockel sind nicht pickbar. Offen: alles wie heute. „Sichtbar heißt bedienbar“ gilt weiter.
2. **Wertung.** Die Anzeige zeigt schon heute den sicheren Wert (`ComboPartEffects.display_values`).
   Neu: weicht er vom Grundwert ab, steht der Grundwert klein und gedimmt daneben („45 ×8“).
3. **Module ruhen gedimmt** (etwa 40 % ihres Lichts) und leuchten voll, wenn sie feuern
   (`flash_socket` gibt es schon). Die Leitung pulst beim Feuern von links nach rechts.
4. **Gewürfelte Hand:** Gold nur an Gehäuse, Pins, Frontband und Leitung. Sockel, Platten und
   Module behalten ihre Farben (`set_glow` faßt sie nicht an).
5. **Die Leitung zeigt die Stärke:** hinter jedem besetzten Sockel wird sie nach der Familie des
   Moduls dicker/heller/doppelt (Tabelle `OUT_LINE` im Blender-Skript: gleich, dick, hell, doppelt,
   stark); es gilt jeweils das Maximum der bisherigen. Gedrosselt: Leitung aus.
6. **Brücken und Kopplung** bleiben auf ihrer Platte. Ihre Wirkung zeigt ein Lichtpuls über die
   bestehenden Sammelschienen zum Nachbarn (`flash_activation` gibt es; der Puls ist neu, klein).
7. **Erweiterungsplatine:** die Mechanik bleibt (`ComboPartEffects.socket_parents`, Platine trägt
   zwei Plätze). Geometrie: die Platine sitzt auf ihrem Sockel und trägt zwei volle Platten
   hintereinander (quer zum Chip), sie ragt dafür vorn und hinten über das Gehäuse. Verschachtelte
   Platinen: so einfach wie möglich halten und im Bericht nennen, was nicht paßt. OFFEN.

## Wellen

### Welle A - Chip, Sockel, Verhalten (table/, scene_root, Tests)

1. `TableScreen`: `CELL_SIZE.x` 133er-Breite, Cluster rechtsbündig wie bisher; alles, was am
   Cluster mißt (Adernetz, Hub-Ader, Energie-Ring, Kamera-Station KOMBINATIONEN, Klickzone,
   Debug-Knopf), nachziehen. Nichts darf über x 0 oder unter die Fumble-Automaten geraten.
2. Chip-Modell ohne Verzerrung: neues `chip_wide.glb` aus `tools/blender_combo_hardware.py` (ohne
   eingeformte Buchsen, Länge passend) - oder das Gehäuse code-gebaut, wenn das einfacher ist.
   Pins und Frontband bleiben erkennbar dieselben. `pin_offsets_px` bleibt die EINE Quelle.
3. `ComboChipView`: Deckel-Layout oben, Sockel code-gebaut (Rand, Boden, Kontaktfeld), Platte je
   Modul, Leitung, Abdeckung, Dimm-Regel, Gold-Regel, Grundwert-Zeile. `set_sockets` bleibt der
   EINE Schreiber; `socket_world`, `pick_of`, `set_socket_hover/beckon/lifted`, `play_plug`,
   `flash_socket`, `flash_activation` behalten ihre Verträge.
4. `ComboPartBody`: `PLATE`-Maße einführen; die HEUTIGEN Modelle bis Welle B auf die Platte
   skalieren (sie sind 0,8 groß), damit das Spiel durchgehend läuft.
5. Wurfgruben-Reihe der Modul-Pakete (`_pit_part_bodies`), Einbau-Geist, Umstecken, Debug-Ansicht:
   mit der neuen Modulgröße prüfen. EINE Größe je Ding - das Modul ist überall gleich groß.
6. Tests anpassen/ergänzen (`test_combo_sockets`, `test_combos_scene`, `test_combo_and_counter_display`,
   `test_vitrine_geometry` falls betroffen); CLAUDE.md-Abschnitte *Combo chips* und `ComboPartBody`
   in `scripts/table/CLAUDE.md` neu fassen, Kurzform in der Wurzel-CLAUDE.md.
7. Sichtprobe: Übersicht und KOMBINATIONEN-Station, leer / gemischt / voll, nach
   `E:/Generated Images/Fumble/kombi_grosschip_spiel/`.

### Welle B - die 26 Module (tools/, assets/, ComboPartBody)

Nach `docs/plan_modul_bauteile.md` (Familien, Bauteil je Modul) und den Blockmodellen. Jedes Modell
neu in `tools/blender_part_models.py` auf der PLATTE, Hüllmaß einhalten, Höhe = Seltenheit.
Zustand am Körper (Zählwerk-Ziffern, Fehlerlampen, Schwingkreis-Ring, Reihenklemmen-Lampen,
Anlasser, Nachbrenner, Thermistor-Rand) und die Punktreihe der Würfel-Module setzt Godot
(`ComboPartBody`), nicht das glb. Die Kopplung zeigt das kopierte Modul als Abbild.

## Lauf-Regeln für jede Welle

- Godot: `E:/Godot/Godot_v4.7-stable_win64_console.exe`. Jeder Lauf im VORDERGRUND mit Timeout,
  nie im Hintergrund, nie zwei zugleich. Proben und Boots immer mit `--quit-after N`.
- Während der Arbeit nur EIN Testskript per `-gselect`; die volle Suite GENAU EINMAL am Ende, danach
  `grep -c "Ignoring\|Parse Error"` im Log. Nach Änderungen an `scene_root.gd` ein Boot
  (`--headless --quit-after 200`). `--import` einmal nach neuen `class_name`s oder neuen glb.
- Gerenderte Proben off-screen: `--resolution 1280x720 --position 4000,2400`.
- Kommentare: kurze deutsche Einzeiler, nur Nicht-Offensichtliches.
- Im Arbeitsbaum liegt eine fremde, uncommittete Welle (Glückswürfel). Nichts davon zurückdrehen,
  nichts committen, nur die eigenen Stellen anfassen.
