# Plan: Platzhalter-Klänge für das ganze Spiel (2026-11-16)

Spieler-Wunsch: überall, wo das Spiel einen Klang bräuchte, einen PLATZHALTER setzen. Bisher klingen nur Würfel-Physik (`DiceAudio`), Wertung (`ScoreAudio`), Schatullen-Öffnung (`CaseShow`) und Musik (`MusicDirector`). Alles andere ist stumm.

## Grammatik (bindend)

- **EINE neue Klasse `SfxBank`** (`scripts/table/sfx_bank.gd`, `extends Node`), nach dem Muster von `ScoreAudio`: Platzhalter werden beim Start synthetisiert (`_render`-Helfer wie dort, 16-Bit-Mono 44,1 kHz), und eine Datei gleichen Namens unter `SFX_DIR` (`.wav`/`.ogg`) ersetzt den Ton ohne Code-Änderung.
- **`const SFX_DIR := "res://assets/sfx/game/"`** — genau EINE Konstante dieses Wortlauts, und jeder Platz als WÖRTLICHER Aufruf `_load_or(&"name", …)` in einem Dictionary-Literal. Die Klang-Tafel (`E:/Godot/klang-tafel`) liest genau dieses Muster per Regex, um die Plätze für „Im Spiel ersetzen“ zu finden — kein Name aus einer Schleife oder Konstante zusammensetzen.
- Namen: `kategorie_ereignis` in snake_case (z. B. `ui_click`, `shop_buy`, `bench_latch`).
- **API**: `play(name: StringName, db := 0.0, pitch := 1.0)`. Jeder Platz hat einen Grundpegel und optional eine Mindestpause (`MIN_GAP_MS` je Name, gegen Geknatter bei Chips/Hover) und eine leichte Tonhöhen-Streuung. Unbekannter Name = still (kein Fehler).
- **Busse**: `ui_*` auf `UI`, alles andere auf `SFX` (beide stehen in `default_bus_layout.tres`; fehlt einer, Rückfall `Master` — wie `ScoreAudio.BUS_NAME`). Je Bus ein `AudioStreamPolyphonic`-Player (polyphony ~24).
- **Buttons global**: `SfxBank` hört `get_tree().node_added` und verbindet jeden `BaseButton` (auch in SubViewports — derselbe Baum) mit `ui_click` beim `pressed` und einem sehr leisen `ui_hover` beim `mouse_entered` (Mindestpause ~60 ms; nur wenn der Button nicht `disabled` ist). Bestehende Buttons beim Start einmal durchgehen. Ein Button kann sich per Meta `sfx_silent` ausnehmen (für Klick-Fänger wie die Laden-Stellplätze, deren Kauf schon `shop_buy` spielt).
- **Wann klingt es**: am SICHTBAREN Moment (Ankunft, Einschlag, Aufschlag des Deckels), nicht an der Buchung — die Buchung läuft vor dem Licht, der Klang gehört zum Licht. **Harte Wege sind stumm**: `settle_hard`, Laufwechsel, Neuaufbau, Vorbau, `_settle_pack_openings`, Spielstand laden — nichts davon spielt einen Klang. Wo ein Rückblick/Protokoll-Nachspiel läuft, schweigt es wie bei `ScoreAudio`.
- `scene_root` besitzt EINE Instanz (`sfx_bank`, angelegt in einem Setup-Schritt neben `_setup_score_audio`) und ruft `sfx_bank.play(...)` an den Hook-Stellen. ui/ ruft die Bank NICHT direkt; Fenster melden über ihre bestehenden Signale, scene_root spielt.
- Kommentare: nur kurze deutsche Einzeiler (siehe CLAUDE.md).

## Synth-Rezepte

Platzhalter, keine Kunst — aber unterscheidbar und nie schrill. Ein paar parametrisierte Rezepte genügen (alle mit Attack ≥ 2 ms und Ausblende am Ende, siehe `_render` in `ScoreAudio`):
- `click` (sehr kurzer Klick/Tick), `blip(freq, len)` (Sinus mit Oktave, Abklingen), `chime(chord, len)` (Glocken-Akkord), `whoosh(len, up)` (gefiltertes Rauschen mit Hüllkurve), `thud(freq, len)` (tiefer, abfallender Schlag), `buzz` (kurzer dumpfer Fehlerton, zwei tiefe Rechteck-artige Töne), `clack` (Chip: kurzer Rausch-Klick + hoher Ton), `zap` (abwärts gleitender Ton), `tear` (Rauschstoß, länger), `latch` (metallischer Doppel-Klick).
- Tonal bleibt alles in G-Moll-Pentatonik (die Musik, siehe `scripts/table/CLAUDE.md` *Die MUSIK*).

## Plätze und Hook-Stellen

Die Funktionsnamen stammen aus einer ersten Suche; die genaue Zeile sucht die Umsetzung selbst (immer den SICHTBAREN Moment).

**UI und Kamera**
- `ui_click`, `ui_hover` — global über die Buttons (siehe oben).
- `ui_denied` — ein abgelehnter Klick: Kauf bei vollem Lager / zu wenig Geld (`ShopController` lehnt in `buy_*`/Sitz-Logik ab — Signal ergänzen oder an der bestehenden Ablehnung in scene_root hängen), Öffnen in der Runde (`_store_unlocked` falsch beim Klick).
- Kamera-Zoom bleibt STUMM (Spieler-Entscheid 2026-11-16).

**Runde**
- `round_start` — neue Runde / Blind beginnt (`_start_new_round`, nur im echten Spiel, nicht beim Reset).
- `round_commit` — Zurren der Runde (`_commit_round`: Vertrag unterschrieben bzw. erster Wurf).
- `dice_throw` — Abwurf-Whoosh (`_on_throw_button_pressed` bzw. dort, wo der Wurf wirklich losfliegt).
- `dice_take` — Nehmen/Kassieren der Hand (`_on_take_button_pressed`, Beginn der Zeremonie).
- `dice_swallow` — ein Würfel versinkt im Tisch (`_swallow_dice`, je Bahn beim Einsinken; Mindestpause).
- `fumble` — Fumble (`_on_farkle`).
- `round_won` — Runde geschafft (`_on_round_complete`).
- `game_over` — Lauf verloren (dort, wo `game_over_panel` sichtbar wird).

**Geld, Energie, Chips**
- `chip_in` / `chip_out` — Chip läuft ins Tray / verlässt es (`_on_tray_chip_entered` / `_on_tray_chip_left`; Mindestpause ~30 ms, Tonhöhe leicht nach Rinne/rank).
- `money_arrive` — Zahl-Komet kommt an (`_on_payment_comet_arrived`).
- `energy_gain` / `energy_spend` — `_on_energy_changed` (Richtung aus alt/neu).

**Laden, Lager, Pakete**
- `shop_buy` — jeder Kauf (`_on_pack_purchased`, `_on_card_pack_purchased`, `_on_dice_pack_purchased`, `_on_module_pack_purchased`, `_on_secret_goods_purchased`, `_on_secret_die_purchased`, `_on_secret_part_purchased`, Charm-Kauf über `_on_charms_changed` nur bei Zuwachs im Laden).
- `shop_refund` — `_on_pack_refunded`.
- `shop_flip` — Blättern/Neuwurf des Sortiments (wo `swap_to`/`_swap_slit_cells` angestoßen wird).
- `store_land` — Paket landet im Lager (Ende des Bogens in `_fly_into_store`).
- `store_open` — Paket wird aus dem Lager geöffnet (`_open_stored_pack`).
- `pack_burst` — Karten-Kassette bricht auf (`_choice_hull.burst()`).
- `bag_tear` — Modul-Beutel reißt (`tear_open()`).
- `pack_pick` — Option gewählt/abgewählt in `PackChoiceView` (Signal ergänzen, falls keins existiert).
- `pack_confirm` — `_on_pack_choice_confirmed`; `pack_reshuffle` — `_on_pack_choice_reshuffle`.

**Werkstatt**
- `card_lift` / `card_drop` — Karte vom Magazin in den Turm bzw. zurück (Start von `_carry_data_cell` / Ankunft von `_return_data_cell`).
- `shelf_switch` — Tablett-Wechsel (`_on_tray_requested`); `shelf_snap` — Rollen rastet ein (`_on_shelf_scroll_snapped`, leise).
- `bench_target` — Zielwürfel gewählt (`_on_workshop_target_chosen`).
- `bench_press` — Prägen startet (`_on_press_started`); `bench_latch` — Karten rasten ein (`_on_cards_latched`); `light_pass` — Licht passiert eine Karte (`_on_light_passed`, Tonhöhe steigt je Etage); `light_strike` — Funken schlagen in den Würfel (`_on_light_struck`); `card_burnout` — Karte brennt aus (`_burn_out_card`, Mindestpause).
- `raster_toggle` — Raster-Umschalter (wo `RasterSwitchView` gedrückt wird); `pool_swap` — Würfel in die Rasterzelle getauscht (`_on_deck_glass_cell_pressed`, wenn wirklich getauscht).

**Wetten, Automaten, Module**
- `bet_place` — `_on_side_bet_placed`; `bet_win` / `bet_lose` — wo eine Wette als erfüllt/gescheitert in den Lebenszyklus wechselt (`_bet_fulfilled`/`_bet_failed`).
- `slot_spin` — `_on_slot_spin_paid`; `slot_win` — `_on_slot_cashed_out`/`_on_slot_prize_dispatched`.
- `part_install` — Modul eingebaut (nach erfolgreichem `install_pending_part`); `part_move` — Modul umgesteckt.
- `charge_burn` — ein Würfel brennt durch (die Durchbrenn-Zeremonie, siehe `scripts/table/CLAUDE.md` *Die Zeremonien der LADUNG*).

Fehlt eine dieser Stellen oder liegt sie anders als gedacht: die nächstliegende sichtbare Stelle nehmen und im Bericht nennen. Weitere offensichtlich stumme Momente dürfen ergänzt werden (im Bericht auflisten).

## Tests und Läufe

- Neuer Test `test/unit/test_sfx_bank.gd`: jeder Name im Bank-Dictionary liefert einen Stream (Platzhalter oder Datei); jeder Name folgt `kategorie_ereignis`; `play` mit unbekanntem Namen ist still; die Mindestpause greift; ein `sfx_silent`-Button bekommt keine Verbindung.
- Ein Grep-artiger Test oder Regex-Prüfung, dass jeder Platz als wörtliches `_load_or(&"…"` im Quelltext steht (die Klang-Tafel verlässt sich darauf).
- Während der Arbeit NUR `-gselect=test_sfx_bank` (3 s). Nach `class_name SfxBank` EINMAL `--import`. Nach den scene_root-Änderungen das Spiel EINMAL headless booten (`--quit-after 200`). Die volle Suite NICHT fahren — sie läuft erst vor dem Commit, und committet wird nicht.
- Jeder Godot-Lauf im Vordergrund mit Bash-`timeout` (Probe/Boot 120 s, Import 300 s) und `--quit-after`; NIE `run_in_background` für Godot, kein `sleep`-Polling.
