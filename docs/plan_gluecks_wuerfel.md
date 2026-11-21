# Plan: Der GLÜCKSWÜRFEL (Spieler-Entscheid 2026-11-21)

Der kleine goldene Würfel ersetzt JEDE Wahl-Rechnung der Pakete. Er liegt dauerhaft auf dem
Tisch, wächst mit dem Glück, und sein Wurf beim Öffnen IST die Zahl der Wahlen.

## Die Regel

- Sechs Seiten, Start 1/1/1/1/1/1. Zusatz-Augen `k` = größtes k mit k·(k+1)/2 ≤ Glück
  (Schwellen 1, 3, 6, 10, 15, 21 …). Deckel je Seite 6, also höchstens 30 Zusatz-Augen.
- Jedes neue Auge fällt auf eine ZUFÄLLIGE Seite, die noch unter 6 steht (1/1/1/1/1/5 ist
  möglich). Die Verteilung ist Laufzustand und wird gespeichert.
- Sinkt das Glück unter eine Schwelle, geht das ZULETZT gewonnene Auge wieder (Stapel).
- Das Glück des Würfels ist `GameRun.effective_luck()` (Glück + Glückspilz). Das Glück der
  Paket-GÜTE (`pack_luck`, +6/+12) wirkt NICHT auf ihn — es bleibt für den INHALT
  (Seelen-/Runen-Chance, Zugabe-Kette der Würfelzahl, Kartengrößen).
- Jedes Paket: Wahlen = Wurf, gedeckelt auf die Zahl der Optionen. Mehr gibt es nicht.
  - Karten-Paket: Optionen 3/4/5 wie bisher (+ Beigabe/Beipack − Verplombt).
  - Würfel-Paket: darf ALLE Würfel nehmen (Deckel Zahl − 1 fällt).
  - Modul-Paket: zeigt wieder Optionen nach Größe (`CardPack.OPTION_COUNTS` 3/4/5/5, alle
    fallen in die Wurfgrube), der Wurf sagt, wie viele man EINBAUEN darf; der Rest wird
    mit dem Beutel eingezogen. `MAX_CONTENTS` und `content_count` sterben.
- FREIE HAND wird zu „Erstes geöffnetes Paket: +1 Wahl“ (Winkeladvokat: +2), auf den Wurf
  addiert, weiter gedeckelt auf die Optionen.
- Es sterben: Klausel ZUGABE (`BONUS_PICK`, `pack_pick_bonus`), Klausel GLÜCKSGRIFF
  (`LUCKY_GRAB`, `pack_luck_factor` samt aller `factor`-Parameter), Hauptgewinn
  (`jackpot`, `take_all`, `QUALITY_JACKPOT`, `JACKPOT_*`), `CardPack.roll_picks`/
  `lucky_chance`/`BASE_PICKS`/`LUCKY_*`, `DicePack.roll_picks`/`base_picks`/`EXTRA_PICK_*`/
  `max_picks`, `PackChoice.base_picks`/`free_hand`/`take_all`/`jackpot`, die WALZE
  (`PackChoiceView` Reel, `reel_*`-Signale, `CaseShow.play_reel_*`/`reel_pitch`).
- PREISE bleiben in dieser Welle Zahl für Zahl stehen: wo eine Formel an erwarteten Wahlen
  hing (`CardPack.price_of`, `ModulePack.PRICES`), wird der bisherige Wert als feste
  Tabelle eingefroren. Balancing ist eine spätere Zahlenänderung.

## core/ und data/

- Neu `LuckDie` (core/, RefCounted, rein): `faces: Array[int]`, `gained: Array[int]`
  (Seiten-Stapel der Zusatz-Augen), `static pips_for(luck)`, `static next_threshold(luck)`,
  `sync(luck, rng) -> Array` (je Änderung `{face, delta, value_after}`), `roll(rng) -> int`
  (Seiten-Index), `value(face)`, `to_dict`/`from_dict`.
- `GameRun.luck_die`, `sync_luck_die(rng)` (EIN Schreiber; gerufen nach jeder Glücks- und
  Charm-Änderung: `add_luck`, `advance_round`, Charm-Kauf/-Verkauf, `new_run`, Laden eines
  Spielstands), Signal `luck_die_changed(changes)`. Buchung vor dem Licht.
- `_open_pack`/`_roll_dice_choice`/`purchase_module_pack`: `choice.die_face` (gewürfelte
  Seite), `choice.die_value`, `choice.picks`. Modul-Paket: `module_keeps` (Wurf, gedeckelt)
  als Laufzustand; `install_pending_part_at` zählt für `from_pack`-Module herunter, bei 0
  verfallen die übrigen Paket-Module (`discard`-Weg), Rückgabe für die Zeremonie.
- `luck_hint()` nennt die nächste Augen-Schwelle. Pakettexte (`info_body`, `content_line`):
  statt „mit Glück mehr“ → „Der Glückswürfel sagt, wie viele.“
- Spielstand: `luck_die` mitschreiben/-lesen (den Speicherweg von `luck` suchen).

## Der Körper (table/)

- Neu `LuckDieView`: golden, eine Spur kleiner als ein Würfel (`SCALE` = 0,75 ×
  `DiceTrayView.DIE_SCALE`, EINE Größe überall), ECHTE AUGEN statt Ziffern (Pip-Layouts
  1–6 je Seite, als Geometrie oder gebackene Maske; unter der Bloom-Schwelle, eigenes
  Licht — der Tisch beleuchtet nichts). `seat_hard(faces)` ist der EINE Schreiber,
  `settle_hard()` der harte Weg.
- PLATZ: auf dem Filz rechts neben der Öffnungs-Fläche, oben bündig mit dem Pool, eine
  Fuge daneben; gerechnet in Display-px, gemeldet wie die Schale (kein Loch, kein Fenster).
  Maße messen und in die CLAUDE.md schreiben; nichts über x 5094.
- AUGE GEWINNEN/VERLIEREN (aus `luck_die_changed`): der Würfel dreht die Seite nach oben,
  das Auge poppt golden auf bzw. verglimmt, dann zurück in die Ruhelage. Die Ansicht hält
  den ALTEN Stand bis zu diesem Schlag (Muster `_charge_holds`); mehrere Änderungen
  nacheinander; Endzustand zuerst.
- DER WURF (bei JEDEM Paket, auch bei lauter gleichen Seiten): kein freier Physik-Wurf —
  gebucht ist längst. Geführter Wurf (Hüpfer, Trudeln, Aufsetzer, landet auf
  `choice.die_face`), ~0,9 s, ein Klick springt ans Ende. Er nimmt den Takt der toten
  Walze: nach dem Enthüllen der Optionen, erst mit seinem Stillstand nennt das Fenster die
  Wahlen (`PackChoiceView`: Stufe statt Reel, Zähler/Knopf wie bisher). Töne: die
  Walzen-Töne von `CaseShow` umwidmen.
  - Karten- und Würfel-Paket: er würfelt AN SEINEM PLATZ; beide Öffnungs-Rahmen
    (`_card_opening_frame_px`, `_dice_opening_frame_px`) schließen ihn ein.
  - Modul-Paket: er fliegt im Trage-Bogen in die WURFGRUBE neben die Modul-Reihe, würfelt
    dort, bleibt bis der Beutel eingezogen ist und fliegt heim. Neue benannte AUSNAHME im
    Bewegungs-Gesetz (ein Wurf, kein Hub).
- INSPEKTION: Doppelklick auf ihn öffnet dieselbe Inspektion wie der Podest-Würfel
  (temporärer Rahmen, Zug dreht, Rechtsklick zurück; `_die_focus_home` verallgemeinern).
  Hover nennt überall „Glückswürfel · Glück n · nächstes Auge bei m“. Nicht während eines
  modalen Rahmens (Zwang, Öffnung, Einbau).
- Harte Wege: Laufwechsel, `_settle_pack_openings`, `_settle_module_bag_hard` setzen ihn
  hart heim mit dem gebuchten Stand.

## Tests und Doku

- Neu `test/unit/test_luck_die.gd` (Schwellen, Deckel 6, Stapel-Rücknahme, Wurf nur über
  vorhandene Seiten, Roundtrip). Anpassen: `test_pack_choice`, `test_card_pack`,
  `test_module_pack`, `test_deal_clause_text`, `test_pack_choice_view`, `test_case_show`,
  alles, was `BONUS_PICK`/`LUCKY_GRAB`/`jackpot`/`reel` nennt.
- CLAUDE.md (Wurzel: *Die PAKET-AUSWAHL*, Bewegungs-Gesetz, Sichtbar heißt bedienbar;
  core/, data/, table/, ui/) knapp nachziehen — Gestorbenes streichen statt erzählen.

## Lauf-Regeln

Nur `-gselect` auf das eine Skript in Arbeit; die volle Suite EINMAL am Ende; danach ein
Boot (`--quit-after 200`), weil `scene_root.gd` angefaßt ist. Jeder Godot-Lauf im
Vordergrund mit `timeout` und `--quit-after`; nie `run_in_background`. `--import` einmal
nach den neuen `class_name`s. Sichtproben nach `E:/Generated Images/Fumble/gluecks_wuerfel/`.
Nicht committen.
