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

## Welle C - der KOMPAKTE Chip: Module als PINS, Sockel fahren aus (Spieler-Entscheide 2026-11-21)

Stand: GEBAUT (2026-11-21). Abweichungen: Modul-Pin 0,9 × 0,56 statt bis 1,1 × 0,73 (die Pin-Reihen stehen
0,625 Welt auseinander, und der Pin muß samt Sammelschiene in die Spaltenfuge passen); 23 Module, weil die
parallele Welle Thermistor und Magnetron strich. Siehe *Combo chips* in `scripts/table/CLAUDE.md`.

Anlaß: der breite Chip machte das Feld zu breit, von der Grube aus waren nicht alle Kombinationen
zu sehen. Sichtproben: `E:/Generated Images/Fumble/kombinationen_module_16_2026-11-21/`
(`u_stifte_blatt_station.png` = alle 25 Pins groß, `t_stifte_station.png` = das Feld in beiden
Zuständen). Blockmodelle: `tools/blender_combo_module_variants.py` (`chip_stift`, `PINS`, `pin_*`,
`p_bar`/`p_block`/`p_fork`/`p_tube`/`p_blade`).

### Entscheide
1. **Zwei Zustände des Chips.**
   - KOMPAKT (Regel): Anzeige, Frontband, links drei Pins, rechts eine Endkappe mit drei
     Kacheln und den drei MODUL-PINS. Keine Sockel sichtbar.
   - AUSGEFAHREN: zwischen Anzeige und Endkappe steht die Sockelzone mit den drei Sockeln
     (Welle A, unverändert in Platte, Rand, Kontaktfeld) und den vollen Modulen (Welle B).
2. **Wann ausgefahren:** genau dann, wenn die Kamera an der KOMBINATIONEN-Station steht ODER
   ein Einbau/Umstecken läuft (Einbau-Rahmen, Modul-Beutel in der Grube, gezogenes Teil). Sonst
   kompakt - auch im Laden aus der Übersicht und in der ganzen Runde. EIN Entscheider in
   scene_root, je Bild gefragt; Endzustand zuerst, ein harter Weg.
3. **Jeder Sockel gehört zu EINEM rechten Pin** (Sockel 0 = oberer, 1 = mittlerer, 2 = unterer
   im Bild). Ist der Sockel leer, ist der Pin ein schlichter Stahlpin. Trägt er ein Modul, IST
   der Pin dieses Modul: Form nach Familie, Zeichen und Details je Modul (Tabelle im
   Blender-Skript, 25 Stück), Licht in `ComboPart.tint()`. Hinter jedem Pin liegt auf der
   Endkappe eine Kachel mit einem Lichtstrich in der Modulfarbe (leer: dunkel).
4. **Ausgefahren läuft je Sockel eine EIGENE Leitung zu SEINEM Pin** (drei parallele Leitungen).
   Die eine Signalleitung durch alle Sockel und die Stärke-Regel (`LINE_STYLE_OF`) entfallen.
5. **Die Abdeckung leerer Chips entfällt** (kompakt sind die Sockel ohnehin fort).
6. **Die ERWEITERUNGSPLATINE verschwindet aus dem Spiel**: `ComboPart.EXPANSION_BOARD`, ihre
   Fabrik, Katalog-Eintrag, `socket_parents`, alle Platinen-Geometrie (riser), Lexikon-/Hinweis-
   Texte, Tests. Jeder Chip hat fest drei Sockel. Es bleiben 25 Module.
7. Regeln sonst unverändert. Nachbarschaft bleibt 3 Spalten (`CLUSTER_COLUMNS`).

### Geometrie (Richtwerte, an der echten Tiefe 2,84 Welt messen)
- Kompaktes Gehäuse ≈ 6,3 Welt lang (Anzeige wie heute + Endkappe ≈ 0,7), Tiefe unverändert.
- Modul-Pin: höchstens 1,1 lang × 0,73 tief, Pin-Reihen wie heute an den drei Pin-Höhen.
- Das Feld steht in BEIDEN Zuständen rechtsbündig an der Grube (Pin-Spitzen `PIT_SIDE_GAP`
  davor). Kompakt ist die Zelle schmal, ausgefahren breit wie heute: beim Wechsel gleiten die
  Zellen seitlich, die Anzeige wandert nach links, Adernetz, Klickzone, Kometen-Anker und
  Kamera-Rahmen der Station folgen dem ENDZUSTAND. Während der Fahrt darf nichts falsch
  verdrahtet stehen (Adern mitführen oder für die Fahrt ausblenden).
- Erwartung: das kompakte Feld ist deutlich schmaler als vor dem Großchip (damals 1285 px).

### Verhalten
- **Wertung:** feuert ein Modul, blitzt sein PIN (und kompakt seine Kachel); ausgefahren
  zusätzlich wie bisher Körper und Sockelrand. `flash_socket(slot, strength, die)` bleibt der
  Eingang. Krit-Schlag wie bisher stärker.
- **Zustand am Pin**, wo er auf den Pin paßt: Zählwerk-Ziffern, Fehlerspeicher-Lampen,
  Anlasser (nur vor der ersten Hand hell), Nachbrenner (Flamme nur scharf), Thermistor (Farbe
  der Ladung), Reihenklemme (so viele Schrauben leuchten wie Module stecken, höchstens 3),
  Schwingkreis (Helligkeit oder Windungen mit dem Wachstum). Derselbe Zustands-Schreiber wie
  beim großen Modul (`set_state`), nicht ein zweiter Weg.
- **Hinweis und Pick:** der Pin eines Sockels beantwortet den Zeiger wie der Sockel (Hinweis
  überall; Einbau/Umstecken weiter nur an der Station bzw. im Einbau-Rahmen, also ausgefahren).
- **Gold der gewürfelten Hand:** Gehäuse, Endkappe, linke Pins, Band. Modul-Pins, Kacheln,
  Sockel und Module behalten ihre Farben. Drossel: Pins und Kacheln dunkel.
- **EINE Größe je Ding:** das große Modul auf seiner Platte bleibt die EINE Größe des Moduls
  (Chip ausgefahren, Wurfgruben-Reihe, Flug). Der Pin ist kein zweites Modul, sondern der
  Anschluß des Sockels, der die Form seines Moduls annimmt.

### Lieferumfang
1. Kompaktes Chip-Modell und Endkappe (Blender-Export oder code-gebaut), die Sockelzone als
   ausfahrendes Stück; `ComboChipView` mit `set_extended(on, time)` (Endzustand zuerst,
   `settle_extension_hard`).
2. 25 Pin-Modelle (`tools/blender_pin_models.py` → `assets/models/hardware/pin_<id>.glb`,
   Knoten wie bei den Modulen `Korpus`/`Licht`/`Glas`; Zeichen als Geometrie, Zustand setzt Godot)
   und der leere Pin. Familienform gleich, Modul am Zeichen unterscheidbar; Test: keine zwei
   gleichen Umrisse samt Zeichen, alle im Hüllmaß.
3. `TableScreen`: zwei Cluster-Layouts (kompakt/ausgefahren), ein Schreiber, Adernetz und
   `pin_offsets_px` für beide.
4. scene_root: der Entscheider, Einbau/Umstecken/Beutel-Show gegen den neuen Ablauf prüfen.
5. Erweiterungsplatine entfernen (Punkt 6), Abdeckung und Signalleitung entfernen.
6. Tests anpassen/ergänzen, CLAUDE.md (Wurzel-Kurzform, table/, data/, core/) nachziehen.
7. Sichtproben aus dem Spiel nach `E:/Generated Images/Fumble/kombi_stifte_spiel/`: Übersicht
   und GRUBEN-Station kompakt (leer, gemischt, voll), KOMBINATIONEN-Station ausgefahren, und
   eine kurze Bildfolge des Ausfahrens.

## Welle D - NUR NOCH PINS (Spieler-Entscheide 2026-11-21, nach Welle C im Spiel)

Stand: GEBAUT (2026-11-21). Gemessen: Pin 1,7 × 0,85 × 0,6 Welt, Zelle 319,2 × 130,2 Display-px (Fuge 16,8 px,
Gehäuse zu Gehäuse 2,83 Welt), Feld x 791,2–1782,4. Abweichungen: an der GRUBEN-Station mißt ein Pin 27 × 13
Bildschirm-px statt der erhofften ~35 × 18 (alle zwölf Kombinationen samt Nebenwetten im Bild lassen die Kamera nicht
näher; `PIT_ZOOM_LEFT` 4,5 → 6,0, `PIT_ZOOM_DISTANCE_BONUS` unverändert); die Wurfgruben-Reihe des Modul-Pakets ist
eine SÄULE (Pins untereinander wie am Chip); die Kopplung zeigt ihre Kopie als Feld in der Farbe des kopierten
Moduls statt als Abbild. Sichtproben `E:/Generated Images/Fumble/kombi_nur_stifte_spiel/`.

1. **Der ausgefahrene Zustand stirbt ganz.** Kein Spreizen des Feldes, keine Sockel, keine
   Kontaktfelder, keine Platten, keine Leitungen im Deckel, kein zweites Cluster-Layout. Der Chip
   ist IMMER kompakt. Weder der Klick auf die Kombinationen noch ein neues Modul fährt etwas aus.
2. **Der PIN IST das Modul - überall.** Es gibt nur noch EINEN Körper je Modul: seinen Pin. Am
   Chip, in der Wurfgruben-Reihe eines Modul-Pakets, im Flug, als Zieh-Geist, im Schwarzmarkt,
   in der Debug-Ansicht - überall dieselbe Größe (EINE Größe je Ding). Die großen Modul-Modelle
   auf Platte (`part_<id>.glb`, `ComboPartBody.PLATE` und der Platten-Modus) entfallen.
3. **Der Pin-Platz IST der Steckplatz.** Einbau und Umstecken zielen auf die drei rechten Pins
   des Chips: ein leerer Platz ist der schlichte Stahlpin (beim Einbau atmet er wie früher der
   freie Sockel), ein belegter zeigt sein Modul. Hover-Hinweis, Pick, `play_plug`, Verdrängen,
   Verwerfen in den Beutel: alles wie bisher, nur am Pin. „Sichtbar heißt bedienbar“ bleibt:
   Umstecken nur an der KOMBINATIONEN-Station, Einbau nur im eigenen Rahmen.
4. **Die Pins werden GRÖSSER.** Ziel etwa 1,7 lang × 0,85 tief (Welt; heute 0,9 × 0,56). Dafür
   rücken die drei rechten Pin-Reihen so weit auseinander, wie die Chiptiefe hergibt, und die
   Spalten-Fuge wächst um die zusätzliche Pin-Länge. Die linken Pins bleiben klein.
   Das Feld bleibt rechtsbündig an der Grube; die GRUBEN-Station muß weiter alle zwölf
   Kombinationen zeigen (`PIT_ZOOM_LEFT`, `PIT_ZOOM_DISTANCE_BONUS` nachmessen).
5. **Die Pins werden UNTERSCHEIDBARER.** Die Familie bleibt an Grundform und Farbe erkennbar,
   aber jedes Modul bekommt eine EIGENE Silhouette (nicht nur ein Zeichen auf gleicher Form) und
   ein großes, helles Merkmal. Prüfmaß: an der GRUBEN-Station (rund 35 × 18 Bildschirm-px je
   Pin) sind alle Module einer Familie auseinanderzuhalten; an der Übersicht mindestens die
   Familien. Pins ruhen heller als bisher (nicht mehr auf 40 % gedimmt), feuernd blitzen sie.
   Der leere Stahlpin darf nicht wie ein Modul lesen und nicht wie die linken Pins.
6. Zustand am Pin wie in Welle C (Zählwerk, Fehlerspeicher, Anlasser, Nachbrenner,
   Reihenklemme, Schwingkreis) - größer, wo die neue Größe es erlaubt.
7. Regeln unverändert. Modul-Katalog = was `ComboPart.all()` heute liefert (die Ladungs-Welle
   hat Thermistor und Magnetron entfernt).

### Lieferumfang
- `ComboChipView` ohne Ausfahren (`set_extended`, Sockel, Leitungen, Platten-Körper fort),
  `TableScreen` mit EINEM Layout, scene_root ohne Entscheider - toter Code wird gelöscht.
- `tools/blender_pin_models.py` mit den neuen, größeren Pins; `tools/blender_part_models.py`
  und `part_*.glb` entfallen, soweit nichts mehr auf sie zeigt.
- Wurfgruben-Reihe, Einbau, Umstecken, Schwarzmarkt-Auslage, Debug-Ansicht auf den Pin-Körper.
- Tests und CLAUDE.md nachziehen; Sichtproben nach
  `E:/Generated Images/Fumble/kombi_nur_stifte_spiel/`: Übersicht, GRUBEN-Station (leer,
  gemischt, voll), KOMBINATIONEN-Station, ein Pin-Blatt aller Module in ECHTER Größe an der
  Gruben-Station und vergrößert, Einbau aus dem Modul-Beutel und eines Wett-Moduls.
