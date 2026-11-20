# Plan: Das Magazin als UMLAUFREGAL (2026-11-21)

Spieler-Wunsch nach den Sorten-Trays (`docs/plan_magazin_trays.md`): beim Rollen verschwinden Karten heute, bevor sie die Wand erreichen, und oben/unten bleibt leerer Boden — sie sollen SICHTBAR irgendwohin gehen und von irgendwo kommen, gefällig, verständlich und räumlich glaubhaft. Gewählt aus drei Ideen (Umlaufregal, Rutsche mit Haube, Stapel-Lift): das **UMLAUFREGAL** (Paternoster).

## Das Bild (Seitenschnitt eines Trays; links = Bild-oben/Walze = Welt +X, rechts = Bild-unten/Lichtleiste = Welt −X)

```
 Filz ─────┐                                   ┌─[Lichtleiste]── Filz
           │  [Karte]────────  [Karte]──────── │
     Achse ●══ Lamelle ══════╪══ Lamelle ══════● Achse      ← Sichtfenster: 2 Reihen flach
          ╱                                     ╲
   kippt ╱ weg                                   ╲ schwenkt hoch
        ╱                                         ╲
       ●══ Lamelle ══════════╪══ Lamelle ══════════●         ← Rücklauf: Vorrat kopfüber
```

## Entscheidungen

1. **Jede REIHE liegt auf einer starren LAMELLE** (das heutige Mulden-Stück `Mulde<Reihe>` mit seinen `ACROSS` Plätzen, Saum, Boden/Leuchttisch, Buchse, Geräte-Schmuck). Die Lamellen bilden ein umlaufendes Band um zwei ACHSEN an der oberen und unteren Kante der Grube.
2. **Am Ende KIPPT die Lamelle** um die Achse an ihrer Kante: am Ende, zu dem die Reihen wandern, dreht die vorderste Lamelle samt ihren Karten nach unten weg (bis sie steil unter der Kante hängt und im Schacht verschwindet); am anderen Ende schwenkt die nächste hinter der Achse hoch und legt sich flach ins Fenster. Die Bewegung ist eine reine FUNKTION des Roll-Versatzes (Zug, Einrasten, Rad, Schieber): je Lamelle Lage und Kippwinkel aus ihrem Abstand zum Fenster — kein eigener Tween, also umkehrbar, sprungfrei, und der harte Weg (`settle_scroll_hard`) stimmt von selbst. Der Kipp-Verlauf soll weich lesen (z. B. Winkel wächst glatt über die Strecke, auf der die Lamelle das Fenster verläßt), und im Fenster liegende Lamellen sind exakt flach.
3. **Die KARTE bleibt auf ihrer Lamelle** (sie steckt in der Buchse am Kartenfuß): der Körper (`DataCellView`) kippt mit — Position UND Drehung folgen der Lamelle, bis sie ganz unter dem Tisch ist; erst dann ist sie weggesteckt (`set_tucked`). Das frühe Ausblenden („sobald die Mitte die Wand passiert“, `hidden_at` in der heutigen Form) stirbt. Das SOCKEL-LICHT der Kartenzufuhr gehört zur Lamelle und geht mit ihr über die Kante: eine hereinschwenkende Lamelle trägt Farbe und Licht IHRER Karte schon beim Auftauchen, nicht erst beim Einrasten (die Farben je Lamelle kommen aus dem Rang der Karte, nicht aus dem Fenster-Index).
4. **Kein Platz NEBEN dem Tray**: der Umlauf liegt unter dem Tray selbst. Die WANDTASCHEN oben und unten sterben samt ihren Grenzen (`top_pocket_limit_x`, `bottom_pocket_limit_x`, `_build_pocket*`, `POCKET_*`, die Schlitze `PackPitView.WALL_X_PLUS/MINUS` für das Magazin), ebenso die Vorrats-Blöcke leerer Mulden (`VorratOben`/`VorratUnten`, `_place_spares`) — an ihre Stelle treten die Lamellen des Umlaufs. Die Grube wird ein SCHACHT, tief genug für die hängende Lamelle (gut eine Lamellenlänge, Richtwert ~4,3 Welt statt 1,22); er darf weder den Graben der Walze (oben) noch etwas unter der Lichtleiste/am Displayrand (unten) schneiden und nirgends durchflimmern — die hängende Lamelle bleibt innerhalb der Gruben-Grenzen bzw. so knapp daneben unter dem Filz, daß nichts kollidiert (messen).
5. **Was man sieht**: an beiden Kanten eine sichtbare ACHSE (Welle mit Kettenrädern im Material des Geräts, dreht mit dem Rollen), die kippende Lamelle mit ihrer Karte, dahinter der dunkle Schacht (Wandhaut des Trays, nach unten abdunkelnd; kein Blick ins Leere, kein Flimmern). Die kurze Lücke am Ende während des Kippens bleibt ehrlich mechanisch sichtbar — KEINE Blende. Den Rücklauf selbst muß man nicht ausmodellieren; unter dem Fenster genügt Dunkel. Aus der 15°-Station muß besonders das UNTERE Ende (zur Kamera) gut lesen: die Fläche der Karte ist bis kurz vor dem Verschwinden unter der Lichtleiste zu sehen.
6. **ANSCHLAG an beiden Enden bleibt** (kein endloser Umlauf): Grenzen, Einrasten in ganzen Reihen, Schieber, Rad, Zähler unverändert. Über die Enden hinaus gezogen (heute nach oben unbegrenzt) federt es wie bisher zurück; dort kommen LEERE Lamellen (ohne Karte, Saum leer, Leuchttisch dunkel) herauf.
7. **Lieferung und Flüge**: eine Karte, deren Platz gerade außerhalb des Fensters liegt, landet weiter am Rand ihrer Spalte — neu: sie fliegt auf die Kante und wird von der Lamelle „mitgenommen“ bzw. liegt danach schlicht auf ihrer (verborgenen) Lamelle; keine Karte darf sichtbar in der Luft hängen oder durch die Fassung stechen. Trage-Bögen Magazin ⇄ Walze, Hover-Griff, Rohling, `browse_only`, Hervorhebung, Zurückhalten bleiben für Karten IM Fenster unverändert; eine kippende Karte ist nicht greifbar.
8. **Schichten**: ui/ unverändert bis auf weggefallene Taschen-Fragen (das Fenster rechnet weiter Plätze und Roll-Stand); table/ (`ShelfStackView`, `MagazinTrayDress`, ggf. `PackPitView`) baut Lamellen, Achsen, Schacht und rechnet die reine Kipp-Funktion (als statische/reine Funktion testbar: Versatz + Lamellen-Index → Lage, Winkel, sichtbar); `scene_root` setzt die Karten-Körper nach dieser Funktion (EIN Schreiber je Karte wie bisher) und stellt die Schächte. EINE Größe je Ding: Karten skalieren nie.

## Mitzuziehen
- Tests: `test_shelf_stack_view` (Kipp-Funktion: im Fenster flach, am Ende gekippt, jenseits verborgen; symmetrisch für beide Richtungen; stetig über den Versatz; Achsen vorhanden in allen vier Trays; keine Taschen mehr; leere Lamellen jenseits der Enden; Leuchttisch folgt dem Rang), `test_pack_drawer_view`, `test_workshop_view`/`test_workshop_fixed_layout`, `test_table_screen`, `test/unit/test_vitrine_geometry.gd`, `test_card_recess_view` (der Laden nutzt `build_bay` weiter unverändert).
- Doku: Wurzel-`CLAUDE.md` (Invariante MAGAZIN: Taschen/Weggesteckt-Regel ERSETZEN durch den Umlauf; Bewegungs-Gesetz bleibt), `scripts/table/CLAUDE.md`, `scripts/ui/CLAUDE.md`, mit gemessenen Werten (Schachttiefe, Lamellenlänge, Kippweg).

## Lauf-Regeln für Agenten (Pflicht)
- Arbeitsschleife nur `-gselect=<ein Skript>`; die VOLLE Suite genau EINMAL am Schluß (zweiter Pass nur nach echtem Fehlschlag). Nach dem Lauf `grep -c "Ignoring\|Parse Error"` aufs Log — muß 0 sein.
- JEDER Godot-Start im Vordergrund mit Bash-`timeout` (Suite 600 s, Probe 120 s) und `--quit-after`; nie `run_in_background`, kein Sleep-Polling. `--import` nur einmal nach einer neuen `class_name`.
- Nach Änderungen an `scene_root.gd` EIN kopfloser Boot (`--headless --quit-after 200`), Log auf `SCRIPT ERROR` prüfen.
- Sichtproben BÜNDELN (ein Skript, ein Lauf, alle Bilder), off-screen `--position 4000,2400`; Bilder nach `E:/Generated Images/Fumble/magazin_umlauf/`, nie ins Repo; höchstens 4 Probe-Läufe.
- Kommentare: kurze deutsche Einzeiler. `\`-Fortsetzungen und Tabs intakt, Zeilenenden LF.
- NICHT committen, nicht pushen, keinen Stash anfassen.
