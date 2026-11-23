# Plan: Der Tisch wird eine CRAPS-WANNE (Fassung NOIR)

Spieler-Entscheide 2026-11-22, aus vier Sichtproben-Runden
(`E:/Generated Images/Fumble/tisch_formen_2026-11-22/`, `tisch_formen_casino_2026-11-22/`,
`tisch_craps_mittig_2026-11-22/`, `tisch_craps_material_2026-11-22/`; Skripte `tools/godot_table_*_variants.gd`).

1. **Der endlose Filz stirbt.** Der Tisch ist ein Möbel: eine CRAPS-WANNE um den Inhalt der Anzeige.
2. **Der Grund ist ein gefrästes DECK**, kein Filz - auf der Anzeige wie um sie herum.
3. **Casino zuerst, Technik nur als Akzent.** Die erste Runde (weiße Haube, Steckkarte, Maschinenraum)
   fiel durch: „zu mechanisch, zu wenig Casino“.
4. **Weite MITTEL**: 10 Welt Luft zwischen Inhalt und Wand.
5. **Die WURFGRUBE ist die waagerechte Mitte** des Tischs.
6. **Fassung NOIR**: schwarzer Klavierlack (Zarge, Beine), gestepptes Aubergine-Leder (Reling) mit
   Messing-Keder, Rauch-Pyramiden (Innenwand), Bernstein-Lichtlippe unter der Reling, violettes
   Unterlicht, Messingstange auf der hinteren Ablage, EINE goldene Layout-Linie auf dem Deck.

## Maße (gemessen 1280 × 720, Welt; x = Bild-oben, z = Bild-rechts)

- Anzeige: x −42,4 … 42,4, z −62,4 … 73,44 (84,8 × 135,8).
- INHALT (Fenster, Charm-Leiste, Chip-Rahmen, Wurfplatz des Glückswürfels): x −41,7 … 26,9,
  z −43,7 … 69,2 (68,6 × 112,9). Die Fenster füllen also nur die Mitte der Anzeige.
- Mitte der Wurfgrube: z −0,08.
- WANNE innen: Mitte (−7,4 | −0,08), 88,6 × 158,5, Eckradius 19. Rechts, oben und unten 10 Luft,
  links ein freies BAND von 35,6 (der Inhalt liegt um die Grube schief: 44 nach links, 69 nach rechts).
- Profil von innen nach außen (Probe): Lackfuß 0–2 hoch, Pyramidenwand bis 8,6, Lichtlippe bis 9,3,
  Ablage 4,4 breit auf 9,9, Lederwulst bis 12,2 hoch und 9 breit, Keder, Zarge bis −9, Messingband,
  Unterlicht. Außenmaß rund 118 × 188. Boden des Raums bei −40.
- Die Wand steht links, oben und rechts AUF ungenutzter Anzeige-Fläche. Geschnitten werden muß die
  Anzeige nicht: ihr Rechteck endet überall im Wandkörper (hinten bei x 42,4 zwischen Innenwand 36,9
  und Zarge 51,6; die Ecken liegen innerhalb des Außenradius 33,7). Die Probe schnitt sie trotzdem.

## Stand 2026-11-22

Gebaut sind Welle 1 und der Shader-Teil von Welle 2, „so wie in den Bildern“ (Spieler-Wunsch): Wanne samt abgesenkter Spielerwand, Deck, Layoutlinie, Messingstange, Beine, Technik-Fenster, Teppich. Die Wand ist EIN Netz je Profil-Abschnitt (unbeleuchtet, also ohne Lichtlast - die Segment-Teilung entfällt). Offen: Welle 3 (Kamera) und Welle 4 (echte Materialien, Blender-Requisiten, Glas über dem Fenster).

## Welle 1 — Die Wanne steht

- Neu `scripts/table/table_body_view.gd` (`TableBodyView`, Node3D): baut die Wanne PROZEDURAL aus
  dem Innen-Umriß (gerundetes Rechteck) und einem Profil, das am Umriß entlanggezogen wird - die
  Rechnung der Probe (`sweep`, `normals`, `rounded_rect` in `tools/godot_table_craps_look_variants.gd`).
  Prozedural, weil die Wanne dem Layout folgt (die Anzeige ist schon einmal gewachsen).
  `seat(inner: Rect2, radius)` ist der EINE Schreiber; die Maße kommen als Konstanten aus dem Plan,
  ein Test prüft, daß der gemeldete Inhalt samt `MARGIN` hineinpaßt.
- Die Wand wird in Segmente geteilt (wie die Kacheln von `TableGround`): ein einziges Netz finge alle
  Spill-Lichter und risse `max_lights_per_object`.
- `TableGround` (`scripts/table/table_ground.gd`, `assets/shaders/table_ground.gdshader`, Knoten in
  `scenes/room.tscn`) stirbt. Was er trug, zieht um: der Deck-Ring zwischen Anzeige-Rand und Wand
  (unten 2,6 breit, links 16,9, rechts 5,8) und sein Gruben-Ausschnitt (`pit_bounds`, `MAX_PITS` 48 -
  prüfen, ob außerhalb der Anzeige überhaupt eine Grube liegt; wenn nicht, braucht der Ring keinen).
  `TableScreen.set_ground_material`/`_sync_ground_rect` sterben oder speisen den Ring.
- Der RAUM: ein Teppich bei y −40, der im Dunkel ausläuft (Muster vorläufig, eigene Geschmacksrunde).
- Kein Verhalten ändert sich: Klicks auf die Wand treffen keine Zone.

## Welle 2 — Das Deck

- `assets/shaders/table_felt.gdshader` (Grund der Anzeige, `TableScreen._felt_material`) wird zum
  DECK: dunkles gefrästes Metall mit Platten-Fugen; die Fenster-Aussparungen (`window_rects`,
  `window_radius`) bleiben. Der Deck-Ring der Welle 1 setzt dasselbe Muster in Welt-Koordinaten fort.
- Die goldene Layout-Linie läuft 1,5 innerhalb der Wand - im Anzeige-Bild, wo sie über der Anzeige
  liegt, als Netz auf dem Ring, wo nicht. Beide aus EINER Umriß-Quelle (`TableBodyView.inner_outline`).
- Farbwerte der Fenster gegen das Deck prüfen (`TableScreen.window_style()`, `BACKGROUND_COLOR`):
  sie wurden für violetten Filz gemischt.

## Welle 3 — Kamera

- Die Übersicht rahmt heute die Anzeige; die Wand fällt fast ganz aus dem Bild. Neu rahmt sie die
  Wanne innen und sitzt auf ihrer Mitte (−7,4 | −0,08). Betroffen in `scripts/table/camera_rig.gd`:
  Übersichts-Pose, `TITLE_MARGIN`/`reveal_table`, die Grenzen der Freikamera (`GLIDE_BOUNDS_MARGIN`,
  `FREE_ZOOM_MAX_FACTOR`).
- Jede Station einmal ansehen. Gerechnet verdeckt die Wand nichts: die Stationen schauen 15° aus
  der Senkrechten (`ZOOM_FORWARD`), ein Blick auf den vordersten Inhalt geht 37 Welt über der
  Spielerwand hinweg. Die abgesenkte Spielerseite der Probe (halbe Höhe) ist damit eine reine
  Geschmacksfrage - siehe OFFEN.

## Welle 4 — Materialien und Requisiten

- Leder-Steppung, Lack-Spiegelung und Pyramiden sind in der Probe Shader-Attrappen ohne Szenenlicht.
  Im Spiel: je Material ein Shader mit eingemaltem Licht (das Muster des Projektor-Stahldecks),
  denn auf dem Tisch beleuchtet nichts seinen Nachbarn (`gl_compatibility`).
- Beine und Messingstange als Blender-Modelle (`tools/blender_table_noir.py` →
  `assets/models/hardware/`), je drei Entwürfe wie gehabt.
- Das TECHNIK-FENSTER im linken Band (34 × rund 15): gefaßt in Messing, unter Rauchglas eine Platine
  mit Heatpipes und Rippenblock - der eine Rest der Hardware-Idee. Später darf es reagieren
  (Boss-Runde, Wertung).

## OFFEN (Spieler)

- Spielerwand abgesenkt (Probe) oder ringsum gleich hoch (wie am echten Craps-Tisch)?
- ENTSCHIEDEN 2026-11-23: ins freie linke Band gehört die BANK des Hauses (`TableBankView`), das Technik-Fenster ist gestorben.
- Ein Limit-Schild an der Wand, das den Blind zeigt (Idee aus dem Halbmond-Entwurf)?
- Der Tisch sitzt 7,4 zum Spieler hin: nur die Kamera rückt nach, das Layout der Anzeige bleibt.

## Lauf-Regeln für jede Welle

Arbeit mit `-gselect` auf dem einen Skript, die volle Suite EINMAL am Ende, jeder Godot-Lauf im
Vordergrund mit `--quit-after` und Bash-`timeout`, nie `run_in_background`; nach Änderungen an
`scene_root.gd` einmal booten. Danach `CLAUDE.md` (der Satz „The table has no edge“) und
`scripts/table/CLAUDE.md` nachziehen.
