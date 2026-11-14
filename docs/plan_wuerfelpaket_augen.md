# Plan: Würfel-Pakete nach AUGEN, Güte als ganze Box (2026-11-14)

Spieler-Entscheide 2026-11-14 (baut auf `docs/plan_wuerfelpaket_umbau.md` samt Nachtrag auf):

1. **Die Augen SIND die Grundzahl.** Ein Würfel-Paket hat 2, 3, 4, 5 oder 6 Augen auf seiner Würfelseite, und so viele Würfel kommen standardmäßig heraus. Die Größen Normal/Groß/Riesig gibt es für Würfel-Pakete nicht mehr. Es gibt nie mehr als 6 Würfel.
2. **Die Glücks-Kette füllt höchstens bis 6 auf.** Zusatz-Würfel bleiben (`roll_count`, Chancen unverändert), aber `MAX_COUNT` ist 6 — ein 6er-Paket bekommt nie einen Zusatz-Würfel. Zu-/Abschläge der Klauseln (`pack_option_delta`) bleiben, geklemmt auf 2..6.
3. **Wahlen-Grundzahl je Würfelzahl**: 2 → 1, 3 → 1, 4 → 1, 5 → 2, 6 → 2. Die Wahl-Kette mit Glück bleibt (Deckel `count - 1`).
4. **Die GÜTE ist die ganze Box**: Standard der bisherige Graphit-Lack, Edel ganz SILBER, Royal ganz GOLD (Deckel und Boden, metallisch, gut lesbar auf dem dunklen Tisch — Sichtprobe). Die ECKKAPPEN und die violetten STEINE sterben ganz (Code, Material, `_process`-Puls, Tests, Doku; aus dem Blender-Modell entfernen und neu exportieren, falls Blender verfügbar ist — sonst ausblenden und das im Bericht sagen). Banderole (Sortenfarbe + Symbol), Naht und Schließe bleiben. Das Glück der Güte (+6/+12) und die Preisfaktoren bleiben.

## Daten (`scripts/data/dice_pack.gd`)
- `DicePack.size` trägt künftig die WÜRFELZAHL 2..6 (Feldname darf bleiben oder sauber `count` werden — Agent entscheidet, aber eine Quelle). `SIZES` = [2, 3, 4, 5, 6], `make` klemmt auf 2..6. `base_count(size)` = size; `BASE_COUNTS` stirbt.
- `BASE_PICKS` je Würfelzahl wie oben.
- Preise Standard je Würfelzahl 2/3/4/5/6: Normal 10/14/20/26/32, Seele 20/27/38/50/60, Material und Runen 15/21/30/38/46.
- Laden-Gewichte der Würfelzahl 2/3/4/5/6: 20/35/25/13/7.
- Name: „4er Seelen-Paket“, „6er Würfel-Paket · Royal“ (nicht mehr `CardPack.sized_name`). `info_body` bleibt sinngemäß („Mindestens 4 Würfel · Mindestens 1 Wahl · +6 Glück“).
- Nebenwetten: `SideBet.reward_dice_pair` sucht über die neuen Größen; `DICE_PACK_MIN` prüfen (billigstes Paket ist jetzt 10).

## Körper (`scripts/table/card_pack_view.gd`)
- `CASE_PIPS` stirbt; die Würfelseite zeigt `size` Augen (2..6), Klassik-Muster: 2 diagonal, 3 diagonal, 4 Ecken, 5 Ecken + Mitte, 6 zwei Reihen. Auf Deckel und Rücken wie heute.
- Silber/Gold: eigenes Material für Deckel/Boden nach Güte (die Narbung darf bleiben). Die Würfelseite (helle Platte) muß auf Silber noch lesbar sein — Sichtprobe, notfalls Platte/Augen im Kontrast anpassen.
- Überall, wo eine Würfel-Paket-Größe als `CardPack`-Größe gelesen wurde (`scene_root` ~6302 `"tier": dice_pack.size`, ~9793 `choice.size`, `vitrine_view` ~761, `pack_choice.gd`, `pack_drawer_view`, `shop_controller`, `pack_choice_view`), auf die Würfelzahl prüfen — nichts darf eine 2..6 als Karten-Größe 0..3 indizieren (Arrays wie `CASSETTE_THICKNESS`!).

## Tests
- `test/unit/test_pack_choice.gd`, `test/unit/test_dice_pack*` (falls vorhanden), `test/integration/test_card_pack_view.gd`, `test_pack_choice_view.gd`, `test_shop_controller.gd`, Nebenwetten-Tests: auf 2..6 umstellen statt auskommentieren. Neu: nie mehr als 6 Würfel (auch mit hohem Glück und Klausel-Zuschlag), 6er bekommt keinen Zusatz, Wahlen-Grundzahlen, Augenzahl am Körper = Würfelzahl, keine Kappen/Steine mehr, Edel/Royal-Material unterscheidbar. `test_no_two_case_parts_share_a_face` bleibt grün.

## Docs
Wurzel-`CLAUDE.md` (Paket-Auswahl-Absatz: Grundzahlen, Güte-Darstellung; Lager-Absatz: Eckkappen/Steine erwähnt), `scripts/data/CLAUDE.md`, `scripts/core/CLAUDE.md`, `scripts/table/CLAUDE.md` (Schatullen-Absatz), `scripts/ui/CLAUDE.md`, Obsidian-Seite 46 (`E:\Obsidian Vault\Games\Fumble\`) kurz nachtragen, hier unten ein Abschnitt „Umsetzung“ mit Meßwerten.

## Nicht anfassen
Karten- und Modul-Pakete behalten Klein/Normal/Groß/Riesig. Öffnungs-Fläche (Layout), Lager-Rinnen und Kauf-/Öffnungs-Fluß bleiben, wie sie sind.

## Umsetzung (2026-11-14)
- **Daten:** `DicePack.size` trägt die Augen 2..6 (Feldname geblieben, EINE Quelle); `SIZES` [2..6], `MAX_COUNT` 6, `base_count(size)` = size, `BASE_COUNTS` tot, `BASE_PICKS` 1/1/1/2/2, `PRICES` und `SHOP_SIZE_WEIGHTS` wie oben, Name „4er Seelen-Paket“. `GameRun._roll_dice_choice` klemmt Grundzahl + Klausel auf 2..6. `SideBet.DICE_PACK_MIN` 10, `reward_dice_pair`/`_affordable_pack_sorts` lesen `DicePack.SIZES[0]`.
- **Körper:** `CASE_PIPS` tot; `case_pips` = `DicePack.base_count`, Muster `CardPackView.pip_spots(n)`. Güte = Lack auf `_shell_material` je Güte (`CASE_ALBEDOS`/`CASE_GLOWS`/`CASE_GLOW_ENERGIES`/`CASE_METALLICS`/`CASE_ROUGHNESSES`; Silber und Gold mit Metallic 0,45 und Eigenlicht 0,4/0,45 — mit 0,7 Metallic las Gold braun, Silber grau). Die Würfelseite bekommt einen dunklen RAND (`FACE_RIM` 1,16), sonst verschwand die helle Platte auf Silber. Kappen, Steine, `cap_metal`, `_process`-Puls, `SILVER_*`/`STONE_*`/`CASE_CAP_T` gestorben; Blender-Modell ohne Kappen/Steine neu exportiert (Blender 3.6).
- **Gemessen** (1280 × 720): `max_case_across` jetzt **134,8 Display-px** (vorher 139,6 samt Kappen) — so breit wie die Karten-Kassette; die drei Lager-Rinnen sind damit gleich hoch, **528,3 × 159,0** (vorher 157,4 / 162,2 / 157,4). Laden-Bucht 1004 × 150. Kein `CardPack`-Array wird mit einer Würfel-Augenzahl indiziert: die Hülle verzweigt bei `dice_pack` vor `CASSETTE_THICKNESS`/`option_count`.
- **Sichtproben:** Lager-Rinne mit allen fünf Augenzahlen und drei Güten, je Güte präsentiert, Laden mit drei Auslagen (scratchpad `a_*.png`).
- **Suite:** 3386/3386 grün, 0 „Ignoring“/„Parse Error“ (der erste Vollpass fiel an `test_the_dice_lane_holds_the_widest_case` — „höher als die anderen“ gilt ohne Kappen nicht mehr, jetzt „nie niedriger“). Boot nach dem Kommentar-Edit in `scene_root.gd` sauber.
