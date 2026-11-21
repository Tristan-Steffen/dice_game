# Plan: Die GLÜCKS-STATION rechts neben dem Chip-Tray

Spieler-Entscheid 2026-11-21. Der Glückswürfel bekommt ein festes Zuhause: eine schmale
Station rechts neben dem Chip-Tray, so hoch wie das Tray. Dort liegt er, und die Station
sagt ohne Klick, was er kann. Gewürfelt wird weiter am Paket - er fliegt hin und heim.

## Was die Station zeigt (von oben nach unten)

1. **Titel** „GLÜCKSWÜRFEL“ (klein, Gold).
2. **SITZ**: ein gemalter Ring/Teller, auf dem der Körper (`LuckDieView`) in seiner Ruhelage
   liegt. Die Station MELDET den Sitz (`seat_px()`), den Körper stellt scene_root.
3. **DIE-VIEW**: das aufgeklappte Kreuz des Glückswürfels (4 × 3 wie `DieNetView`), jede
   Zelle eine goldene Würfelseite mit ihren ECHTEN Augen (dunkle Punkte, dieselben Lagen
   wie am Körper). Die Seite des letzten Wurfs trägt einen hellen Gold-Saum, bis neu
   gewürfelt wird. Die Zellen zeigen den GEZEIGTEN Stand des Körpers
   (`LuckDieView.shown_faces()`), also poppt ein neues Auge im selben Schlag wie am Würfel.
4. **Erwartung**: „Ø 2,2 Wahlen“ (Summe der Augen / 6, eine Nachkommastelle, Komma).
5. **Glücks-Pegel**: Balken von der letzten zur nächsten Augen-Schwelle, Zeile
   „Glück 8 · Auge bei 10“ (alle Seiten voll: „Glück n · alle Seiten voll“).
6. **Bonus-Zeile**: nur wenn sie etwas sagt - „Freie Hand +1“ (bzw. +2) mit leuchtender
   Lampe, solange das erste Paket der Runde noch nicht geöffnet ist und die Klausel wirkt;
   ist ein Modul-Beutel offen (`module_keeps > 0`), statt dessen „Noch n Einbauten“.

Nicht gezeigt: Güte-Glück der Pakete (hebt den Würfel nie), Wurf-Historie.

## Schichten

- **core/** `LuckDie`: `PIP_LAYOUTS`/`pip_layout(value)` ziehen hierher (EINE Quelle für
  Körper und Netz; `LuckDieView` liest sie von dort), dazu `NET_LAYOUT` (Kreuz → Seiten-
  Index, passend zu `LuckDieView.FACE_DIRS`: Seite 0 = oben in Ruhe liegt in der Kreuz-
  Mitte, Nachbarn physisch richtig), `expected()` (float), `prev_threshold(luck)`.
  `GameRun.luck_station_state() -> Dictionary` (reine Daten: `luck`, `prev`, `next`,
  `expected`, `free_bonus` (0 = nichts zu holen), `keeps`). Unit-Tests.
- **ui/** `LuckStationView` (Control, `MOUSE_FILTER_IGNORE`, Einheit aus der eigenen
  Breite): malt Fassung (Rezept der Tray-Fassung `TreasureChestView`: Gold-Rahmen, dunkle
  Füllung), Titel, Sitz-Ring, Netz, Zeilen. `set_state(faces, last_face, state)` ist der
  EINE idempotente Schreiber (nur der Wechsel baut/malt neu). Statisch
  `placed_beside(tray_rect, gap)` (Breite = `WIDTH_SHARE` der Tray-Breite, Richtwert 0,6;
  Höhe und Oberkante des Trays). Meldet `seat_px()` (eigene Pixel) und `net_cell()`.
  Kennt weder `GameRun` noch Körper.
- **table/** `TableScreen`: `luck_station_window`, `place_luck_station(rect)`, aufgenommen
  in die Fenster-Rechtecke des Glases wie die Tray-Fassung (`MAX_WINDOWS` prüfen!).
- **scene_root**:
  - Aufstellen in `_setup_table_screen` direkt nach dem Tray; `configure_chips_target` und
    `chips_click_zone` rahmen Tray ∪ Station.
  - `_luck_die_place_px()` = der Sitz der Station (Display-px). Der ALTE Platz neben der
    Öffnungs-Fläche wird der WURFPLATZ `_luck_die_roll_px()`; `_merge_luck_die_place`
    nimmt ihn (die Öffnungs-Rahmen schließen den Wurfplatz ein, nicht das Zuhause).
  - `_luck_away` wird ein Ort: HOME / ROLL / PIT (EIN Schreiber, Endzustand zuerst).
    Karten- und Würfel-Paket: sobald die Öffnung beginnt (Hülle fliegt), fliegt er im
    Trage-Bogen zum Wurfplatz (`carry_to`, wie zur Grube), würfelt dort wie bisher, und
    fliegt heim, wenn die Öffnung endet. Modul-Paket unverändert (Grube → heim).
    Kommt der Wurf-Takt, bevor er gelandet ist: Landung abwarten oder hart landen -
    der Zähler darf nie hängen (`pack_choice_view.die_landed()` kommt IMMER).
  - Harte Wege (`_luck_die_home_hard`, `_settle_pack_openings`, `_settle_module_bag_hard`,
    Laufwechsel) setzen ihn hart auf den Sitz.
  - `_sync_luck_die` schreibt je Bild auch die Station
    (`set_state(luck_die_view.shown_faces(), letzter Wurf, run.luck_station_state())`);
    der letzte Wurf wird in `_on_luck_die_rolled` gemerkt, der Laufwechsel löscht ihn.
  - Hover und Doppelklick-Inspektion bleiben wie sie sind.

## Abnahme

- Die Station steht rechts neben dem Tray, kollidiert mit nichts (gemessen und im Abschluß
  genannt: Rechteck in Display-px, Netz-Zelle in Display- und Bildschirm-px an Übersicht
  und CHIPS-Station bei 1280 × 720). Paßt 0,6 Tray-Breite nicht, schmaler - nie über
  fremdes Möbel.
- Der Würfel liegt in Ruhe auf dem Sitz; jede Paket-Art würfelt wie bisher, danach liegt er
  wieder dort. Kein Zustand, in dem er zweimal oder gar nicht zu sehen ist.
- Netz, Ø, Pegel und Bonus-Zeile stimmen mit `GameRun` überein und folgen Glücks-Änderungen.
- Suite grün (ohne „Ignoring“/„Parse Error“), Boot ohne Skriptfehler.
- Doku: Wurzel-CLAUDE.md (Glückswürfel-Absatz, dritte Ausnahme des Bewegungs-Gesetzes gilt
  jetzt für JEDES Paket), `scripts/table/CLAUDE.md`, `scripts/ui/CLAUDE.md`,
  `scripts/core/CLAUDE.md` - je ein knapper Absatz, alte Aussagen korrigiert.
