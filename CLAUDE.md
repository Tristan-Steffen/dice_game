# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Fumble** — a Balatro-like 3D dice roguelike built in **Godot 4.7** (`gl_compatibility` renderer, Jolt physics). Code comments and in-game text are in **German**; identifiers are a mix. The whole game plays on a single table surface at world **Y = 0**, viewed as a "casino table screen": 2D UI is rendered into a `SubViewport` and displayed on a mesh (see Architecture). The table has **no edge**: the felt runs on as an endless floor that fades into the dark room (`TableGround`), leaving space for future features around the play area.

**Comments:** keep them to the necessary minimum — short German one-liners that state a non-obvious rule, constraint, or design decision. Don't restate what the code already says, don't duplicate a `description` string that sits one line below, and don't write essay-length narrative blocks or "siehe X" cross-reference chains. When in doubt, cut it.

## Commands

The Godot binary lives outside the repo at `E:/Godot/Godot_v4.7-stable_win64_console.exe` (use the `_console` build so stdout/stderr are captured).

**Erzeugte Bilder** (KI-Generierläufe, siehe Skill `asset-gen`) gehören nach `E:/Generated Images/<Projekt>/<Lauf>/` — nie ins Repo; nur der ausgewählte Gewinner wird nach `assets/` kopiert.

```bash
# Run the full test suite (headless, GUT). Exit code is non-zero on failure.
# --fixed-fps 60 koppelt die Frames von der Echtzeit ab (Delta fest 1/60), so
# laufen die wait_frames/wait_seconds der Integrationstests CPU-schnell statt in Echtzeit.
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

# Run a single test SCRIPT (-gtest often falls through to the full suite; prefer -gdir on the file's folder + a unit script, or filter by directory):
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

# Register newly added `class_name`s in the class cache (required after adding a new global class before it resolves in tests/probes):
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . --import

# Run the game:
E:/Godot/Godot_v4.7-stable_win64_console.exe --path .

# One-off visual/logic probe script (ad-hoc scene):
E:/Godot/Godot_v4.7-stable_win64_console.exe --path . --resolution 1280x720 --script <path-to.gd>
```

CI (`.github/workflows/tests.yml`) runs the same GUT command on Linux after a `--editor --quit` import pass — as **two parallel matrix jobs** (`-gdir=res://test/unit` / `res://test/integration`) on separate runners, with `.godot` restored from `actions/cache` (the import pass dominates the job at ~9 min cold; warm it only re-imports what changed). Locally never split the suite into two concurrent Godot processes: one instance already saturates the machine (measured: parallel 135 s vs. serial 65 s). Test config is `.gutconfig.json` (scans `res://test/`, prefix `test_`, suffix `.gd`).

## Architecture

### Layered `scripts/` — the folder IS the dependency rule
`core/` and `data/` must not import from folders below them. New scripts are placed by layer, not by feature:

- **`data/`** — reine `Resource`-Records (inkl. `DealClause`); jede Id als `const`-String (single source of truth). Details: `scripts/data/CLAUDE.md`.
- **`core/`** — pure Logik, **keine Nodes** (`RefCounted`/static): Scoring, Effekt-Auflösung, `GameRun`, Verträge, Energie-Ökonomie. Details: `scripts/core/CLAUDE.md`.
- **`dice/`** — der physische Würfel: Physik, Builder, Face-Display, Schwebe-Stationen. Details: `scripts/dice/CLAUDE.md`.
- **`table/`** — 3D-Requisiten, Kamera und das Tisch-Display samt Bühnenmaschinerie (Vitrine, Hebebühne, Data-Cells, Licht-Routing). Details: `scripts/table/CLAUDE.md`.
- **`ui/`** — 2D-Fenster und Styling im Tisch-Display: Laden, Werkstatt/Presse, Magazin, Wetten. Details: `scripts/ui/CLAUDE.md`.

Die ausführliche Architektur-Doku liegt in diesen verzeichnis-lokalen CLAUDE.md-Dateien; Claude Code lädt sie, sobald dort Dateien angefasst werden. Wer ein Subsystem anfasst, liest die CLAUDE.md seines Ordners zuerst — Querverweise („siehe *X*") können in einer Schwesterdatei liegen.

### `scene_root.gd` — the single coordinator
Top-level `Node3D` (not in a subfolder). Owns exactly one `GameRun`, wires its signals to the UI, drives round flow (throw → score → take/reroll → round-goal → **Auszahlungs-Seite mit Kassieren-Halt** (der Hub wird zur Cash-Out-Seite und die Runde steht, bis „Kassieren" gedrückt ist — siehe *Die AUSZAHLUNGS-SEITE* in `scripts/ui/CLAUDE.md`) → shop — and the **pit is the shop's second exit**: focusing it while `phase == SHOP` means "Fertig", so `_on_camera_mode_changed` calls `ShopController.close()` and `_on_shop_closed` only zooms back to the overview when the camera really stands in the hub, never yanking back a flight already under way), and passes the same `GameRun` instance (typed) to `ShopController` and `WorkshopView`, which mutate state **only** through `GameRun` methods. It also does mouse-forwarding: `_forward_screen_mouse` projects window clicks onto the table plane and `push_input`s them into the `SubViewport` (the projection is camera-independent and runs in every pose, the free camera included); `_screen_forwards_pixel` asks which VISIBLE window owns the pixel — see *Sichtbar heißt bedienbar*. `_ready` is split into named setup steps (`_setup_dice`/`_setup_table_screen`/`_setup_camera_targets`/`_setup_panels`/`_setup_settings_ui`); camera raycasts go through the shared `_ray_pick(pos, mask)` helper and click zones through `_add_click_zone`.

### Globale Invarianten (Kurzform — Volltext in den Ordner-Dateien)
- **Buchung vor dem Licht**: `GameRun` bucht, die Zeremonie zeigt nur an — neue Quellen buchen VOR dem Flug; die wenigen benannten Zeremonien, die bewusst am Einschlag buchen (Bank-Discharge, Frankiermaschine, Geld-Pakete), sind phase-/run-guarded. Nie doppelt.
- **Endzustand zuerst** (`seat_hard`-Regel): jede Fahrt schreibt erst den fertigen Zustand und fährt dann den Weg dorthin; ein abgebrochener Tween darf nichts schulden.
- **EIN idempotenter Schreiber je Körper-Ort**, mit Generations- und Lauf-Marken; jeder Abbruch läuft durch EINEN Aufräum-Pfad.
- **ui/ fasst nie Körper an**: Fenster malen Fassungen und MELDEN Rects/Anker in Display-Pixeln (das `apron_bottom`-Muster); die Körper gehören `scene_root`.
- **Ein Würfel wird nie zweimal gezeigt.**
- **Der TIPP auf einen Neuzugang im Ausgabefach öffnet die GLAS-ANSICHT** (2026-08-31): der Vorrat versinkt, der Gruben-Schirm fährt zu und trägt die Anzeige, und darauf liegt das Netz-Raster des Vorrats — Sitz i = Zelle i. Tipp bucht den Tausch, Zug legt um, Rechtsklick und Wegzoomen brechen ab. **Liegen mehrere Neuzugänge, bleibt die Ansicht nach einer Wahl STEHEN** (die SERIE, 2026-09-01): der nächste rückt ins Fach nach, Kopfzeile und Info-Säule wechseln auf ihn, erst die letzte Wahl schließt — und weil `exchange_pending_die` die Indizes verrutschen läßt, ist der offene Neuzugang IMMER Index 0. Das Raster prüft seine Frische am INHALT (`DeckGlassView.pool_signature`), nicht an den Referenzen: der Tausch schreibt per `become` in die Instanz, die Liste bleibt gleich. Die Kamera fährt dafür ENG heran (Rahmen = Pool-Loch ∪ Neuzugangs-Säule, ~85 % Bildfüllung) und kehrt beim Schließen an die gemerkte Station zurück — es ist ein TEMPORÄRER Rahmen ohne Moduswechsel, sonst bräche die Ansicht sich selbst ab. Die Pool-Maschine kennt dafür eine ZWEITE Park-Konfiguration (tief, mit Schirm); die der RUNDE (flach, schirmlos) bleibt unberührt. Das Raster wohnt seit 2026-08-31 in einem EIGENEN, nicht-HDR-SubViewport mit `transparent_bg`: nur so trägt es echtes Per-Pixel-Alpha (der Helligkeits-Key und die Filz-Schwärzung sind damit gestorben), und seine Auflösung wird an der GEMESSENEN Bildschirm-Pixeldichte des Schirms bemessen statt am fernen Ausschnitt der einen Anzeige — gemessen stieg die Texel-Dichte von 0,44 auf 1,35. Siehe *Die GLAS-ANSICHT* in `scripts/ui/CLAUDE.md`.
- **Der TIPP auf einen VORRATS-Würfel stellt ihn aufs PODEST** (2026-08-31, das Werkstatt-Dossier ist damit gestorben): die Neuzugänge sinken hinter dem VORHANG durch den Fachboden, ein Kraftfeld-Projektor hält den gewählten Würfel an ihrer Stelle, sein Pool-Sitz bleibt LEER (derselbe `_inspected_die`/`DiceTrayView.seat_shows`-Mechanismus wie zuvor) und die Info-Säule darunter zeigt IHN. Er **SCHWEBT dabei wie ein Pool-Würfel** (`PODIUM_HOVER` = `DiceTrayView.FLOAT_HEIGHT`, Spieler-Entscheid 2026-09-01): sein Projektor steht auf dem Fachboden, der Würfel eine volle Pool-Schwebehöhe darüber und wippt im eingerasteten Feld — er liegt nicht flach in der Schale. Rechtsklick und Wegzoomen wählen ab; ein Tipp auf einen ANDEREN Vorrats-Würfel wechselt direkt. Solange er schwebt, ruhen Glas-Ansicht und Tausch-Drag. Siehe `scene_root`s `#region Das PODEST`.
- **Der ZWEITE Tipp auf den Podest-Würfel öffnet die INSPEKTION** (2026-09-01, die 2026-08-31 mit dem Dossier gelöschte `die_focus`-Maschinerie ist dafür zurückgeholt): die Kamera fährt SUPER NAH heran — Rahmen = halbe Raumdiagonale mal `CameraRig.DIE_FOCUS_MARGIN`, gemessen ~7× näher als die Station —, der Würfel legt sich in die Dreiviertel-Ansicht (`die_focus_basis`, drei Seiten auf einmal), die Kamera steht STILL, und ein ZUG dreht IHN um die Bild-Achsen (`FloatingDie.spin`). Es gibt **keinen Seiten-Pick** — hier wird gedreht und geschaut, nicht graviert. Sie ist **MODAL wie die Glas-Ansicht**: im Bild steht nur der Würfel, `_screen_forwards_pixel` schweigt, das Ausgabefach ist kein Klickziel, und WASD wie Doppelklick-Nahsicht sind taub. Wie die Glas-Ansicht ist es ein **TEMPORÄRER Rahmen**: `zoom_die_focus` meldet keinen Wechsel und rührt den Modus nicht an, sonst wählte der eigene Zoom das Podest ab; die Lage davor merkt sich `scene_root._die_focus_home`. Rechtsklick und Rad-zurück gehen **EINE Stufe** aufs Podest zurück (`_leave_die_focus`: `pose_to(FloatingDie.rest_pose())` plus `restore_pose`), erst der nächste wählt ab — Fokus → Podest → Abwahl. Ein Kamerawechsel VERGISST das Zuhause und wählt durch, wie bei der Glas-Ansicht.
- **Das Bewegungs-Gesetz liest sich nach URHEBER**: was der *Spieler zahlt*, fliegt als KÖRPER im ballistischen Bogen (der WURF, `scene_root`s `#region Der WURF`); was der *Tisch liefert*, reist als LICHT über die gelegten Adern; was er *präsentiert oder einzieht*, fährt per HEBEBÜHNE durch die Fläche. Umgesetzt ist der Wurf bisher für den Nebenwetten-EINSATZ — Laden und Werkstatt zahlen noch Licht, ihr Umzug ist eine spätere Welle. Die ABLAGE eines benutzten Würfels ist dagegen ein EINZUG des Tisches und fährt darum per HEBEBÜHNE: eine würfelgroße Sektion öffnet unter seinem Liegeplatz in der Wurfgrube und senkt ihn ein (der SCHLUCK, `scene_root._swallow_dice`; der ballistische Ablage-Flug der Kuhle ist 2026-08-30 gestorben, siehe *Die WÜRFEL-BÜHNE* in `scripts/table/CLAUDE.md`). **Die eine benannte AUSNAHME ist die Wett-STEUER** (`scene_root._fly_bet_tax`): die Kleinsteuer je Hand ist kein Zahl-Moment, sondern ein Ticken, und sie reist darum als Meteor vom Schatz zum Wettfenster, wo der Bedingungs-Text kurz aufleuchtet. Neue Ausnahmen werden hier benannt oder es gibt sie nicht.
- **Die WERKSTATT ist eine SERIENSCHALTUNG** (2026-09-01): jede Gravur-Kassette trägt ein bei der Erzeugung gewürfeltes, überall SICHTBARES Prägenetz (`Pack.stamp_net`); bis zu `series_slots()` Karten stecken in Reihenfolge, `SeriesResolver` summiert sie seitenweise (Operatoren wirken auf die aufgelaufene Summe — die REIHENFOLGE ist die Entscheidung), und EIN Griff je Sitzung projiziert alles auf EINEN spielergewählten Würfel, der per Bühnen-Fahrt aus dem Pool kommt. Presse-RNG, Multicast, Ablage, Platzier-Zweiklick und das Aufspannungs-Los sind tot; der Zufall wohnt im Laden-Angebot. Siehe *Die SERIENSCHALTUNG* in `scripts/ui/CLAUDE.md`.
- **UI-Wort vs. Code-Wort**: Energie/`charge`, Gravur/`Engraving`, Veredelung/`dope`, Pointer (die LED-Adern behalten „Leiterbahn"), Benchmark (nie „Blind"/„Ante").
- **Sichtbar heißt bedienbar**: was bedient werden darf, hängt an Sichtbarkeit, nie an der Kamera-Station. Es gibt genau ZWEI benannte Ausnahmen: der Setzen-Klick des Wett-Tresens (2026-08-26) — gewettet wird nur an der eigenen Station, aus der Ferne wird der Klick zum Zoom — und der Schwarzmarkt-KAUF (2026-08-30): gekauft wird nur an der eigenen Station, aus der Ferne wird der Klick zum Zoom; Hover, Schilder und Tooltip antworten überall, wo die Ware steht. Neue Ausnahmen werden hier benannt oder es gibt sie nicht.

## Arbeitsweise (Spieler-Entscheidung 2026-08-25)
- **Delegiert wird nur bei echten FEATURE-WELLEN** (neue Mechanik, mehrere Subsysteme, Umbau einer Grammatik) — dann Plan-Datei + Opus-5-Subagent wie gehabt. **Kleine Änderungen macht die Session SELBST**: Ein-/Zwei-Datei-Fixes, Konstanten, Farben/Maße, visuelle Tweaks, Bugs mit bekannter Wurzel. Kein Plan-Dokument, kein Agenten-Aufsatz für so etwas.
- **Getestet wird EINMAL AM ENDE**, nicht nach jedem Schritt: ein Suiten-Pass, wenn die Änderung steht (plus Boot, falls `scene_root.gd` angefasst wurde). Kein Wiederholen der Läufe, die ein Subagent gerade grün gefahren hat — sein Log prüfen genügt (immer mit dem `Ignoring|Parse Error`-Grep, siehe unten); der eigene Vollpass gehört vor den Commit.
- **Beweis-Aufwand nach Anlass**: Kennfarben-Aufnahmen, Pixel-A/B und Frame-Serien gehören zur Artefakt-Jagd (dort haben sie dreimal die echte Ursache statt einer Vermutung geliefert) — nicht zu Geschmacks-Änderungen.

## Testing
Notizen und GUT-Eigenheiten: `test/CLAUDE.md`. Tests parsen `scene_root.gd` nie — nach Änderungen daran das Spiel einmal headless booten.
