# Plan: Würfel-Pakete umbauen – Typen, Größen, Güte als Glück, Banderole (2026-11-14)

Spieler-Entscheide aus dem Gespräch vom 2026-11-14 (Design-Grundlage: `docs/plan_wuerfelpaket_design.md`, gewählt ist **Vorschlag 1 – Banderole und Ecken**). Wo der Spieler nichts festgelegt hat, steht hier der Vorschlag der Session (mit „Vorgabe“ markiert) – nicht neu verhandeln, so umsetzen.

## A. Daten und Regeln (`scripts/data/dice_pack.gd`, `scripts/core/dice_offer.gd`, `scripts/core/game_run.gd`, `scripts/core/pack_choice.gd`, `scripts/core/side_bet.gd`)

### Typen
- Es gibt genau vier Sorten: **normal** (`SORT_NORMAL`, UI-Name „Würfel-Paket“ – Vorgabe), **Seele** (`SORT_SOUL`, „Seelen-Paket“), **Material** (`SORT_MATERIAL`, „Material-Würfelpaket“), **Runen** (`SORT_RUNE`, neu, „Runen-Würfelpaket“).
- **Gestrichen**: `SORT_POWER`, `SORT_SERIES`, `SORT_MIXED` samt `SORT_STYLES` (das normale Paket zieht jede Vorlage). Kein Lauf-Spielstand existiert (nur `user://settings.cfg`) – keine Migration nötig, aber jede Stelle, die die alten Sorten nennt (Nebenwetten-Gewinne in `side_bet.gd`, Tests, Texte), auf die neuen umstellen.
- Laden-Gewichte (Vorgabe): normal **50**, Material **20**, Seele **15**, Runen **15**.
- Jede Sorte kann zufällig Seele, Material und Rune bringen; die Sorte GARANTIERT nur ihre eigene Eigenschaft:
  - **Seele**: jeder Würfel beseelt, die Seltenheit eine Stufe gehoben (wie heute).
  - **Material**: jeder Würfel mindestens zwei Material-Seiten (wie heute, `MATERIAL_MIN_FACES`).
  - **Runen**: jeder Würfel mindestens eine Rune; mit der Runen-Chance (unten) eine zweite.
- Grund-Chancen für alle Paket-Würfel (Vorgabe): Seele wie heute `pack_soul_chance(luck)`; Material wie heute Standard (`0,35`, ein bis zwei Seiten); **Rune neu**: `0,15 + 0,015 × Glück`, Deckel `0,5` (eine Rune auf eine zufällige Seite). Veredelung kommt aus Paketen nicht mehr (sie hing an der Güte).

### Größen
- Würfel-Pakete gibt es nur noch **Normal / Groß / Riesig** (3 / 4 / 5 Würfel mindestens, Wahlen 1 / 2 / 2). Das Datenmodell behält die geteilten `CardPack.SIZE_*`-Indizes; Würfel-Pakete würfeln `SIZE_SMALL` nie, und `DicePack.make` hebt Klein auf Normal. Laden-Gewichte der Größe: die bisherigen 40 / 22 / 8 (Klein fällt weg). Karten-Pakete behalten Klein.
- Preise (Güte Standard, Vorgabe; Index = Größe, Klein bleibt als ungenutzter Platzhalter):
  normal `[14, 14, 26, 26]`, Seele `[27, 27, 49, 50]`, Material `[21, 21, 38, 38]`, Runen `[21, 21, 38, 38]`.

### Güte = Glück
- Standard / Edel / Royal geben dem Paket **+0 / +6 / +12 Glück** (Spieler-Entscheid). Dieses Paket-Glück kommt beim ÖFFNEN auf `effective_luck()` drauf und gilt für ALLE Ketten dieses Pakets: Würfel-Zahl, Wahlen, Seelen-Chance, Runen-Chance. Es hebt NICHT `shop_tier()` (die Augen-Vorlagen) – Vorgabe.
- **Gestrichen**: die Güte je Würfel (`DicePack.roll_quality`, Aufstiegs-Kette `UPGRADE_*`, `PackChoice.qualities`/`quality_of`), `DiceOffer.QUALITY_MATERIAL_CHANCE`/`QUALITY_DOPE_CHANCE`/`QUALITY_SOUL_BONUS`/`FINE_SOUL_BOOST`, die Royal-Garantien (veredelte Seite, Rune) und der Augen-Rahmen-Hub `tier + quality` in `roll_pack_die`. Preis-Faktoren und Laden-Gewichte der Güte bleiben.
- `DicePack.info_body`: nennt Sorte, „Mindestens n Würfel · Mindestens k Wahl(en)“ und bei Edel/Royal „+6 Glück“ / „+12 Glück“ statt des Güte-Namens allein.

## B. Die Öffnung (`scripts/ui/pack_choice_view.gd`, `scene_root`)
- Mit der Güte je Würfel stirbt die **Güte-Enthüllung** (`STAGE_REVEAL`, `play_reveal`, `reveal_steps`, `_lock_quality`, `reveal_ticked`/`quality_locked`/`climbed`, Güte-Saum `slot_rim` nach Güte): die Würfel gleiten in die Aufstellung, ihre Netze stehen sofort, und es geht direkt zur WALZE. Ton/Licht-Reaktionen in `scene_root` auf die gestorbenen Signale mit entfernen. `skip_to_pick` und der harte Weg bleiben.
- Was die Option zeigt, bleibt (Netz, Auskunft).

## C. Die Schatulle – Banderole und Ecken (`scripts/table/card_pack_view.gd`, ggf. `tools/blender_dice_case.py`)
- **Größe = echte BREITE**: die Schatulle wird quer (kurze Seite, im Laden die Höhe des liegenden Deckels im Bild, in der Rinne die Strecke quer zur Rinne) mit der Größe breiter – Vorgabe Normal ×1,0, Groß ×1,15, Riesig ×1,3. Dicke und Länge bleiben. Damit gilt für Würfel-Pakete die Regel „EIN Grundriß für alle Pakete“ nicht mehr: `case_outline_local`/`case_interior_local`, `_pack_spine_px`/Rinnen-Höhe, Laden-Bucht (`VitrineView._lay_bowl_hull`), Öffnungs-Fläche (`case_rect_local`, Landefläche, Einzug `PIT_CASE`) müssen die echte (breiteste) Schatulle fassen – prüfen und nachziehen, in der Root-CLAUDE.md die Regel um diese benannte Ausnahme ergänzen. Ob in Godot nicht-gleichmäßig skaliert oder in Blender je Größe gebaut wird, entscheidet der Agent nach Sichtprobe (Ecken dürfen nicht sichtbar verzerren).
- **Augen auf dem Deckel entfallen** (die Größe sagt jetzt die Breite) – `set_pips`/`shown_pips`/`CASE_PIPS` samt Aufrufern aufräumen.
- **Typ = BANDEROLE**: Normal hat keine. Seele/Material/Runen tragen ein breites, leuchtendes Band, das einmal ringsum läuft – quer über den Deckel (mittig), beide Längsseiten hinunter, unter dem Boden durch –, also oben quer über dem Deckel und in der Rinne als Farbblock auf dem Rücken sichtbar. Farben: Seele Opal-Weiß (`#f1e8ff`, Vorgabe), Material Pink `#ff79c6`, Runen Gelb `#ffd319` (dieselben wie die Material-/Runen-Karten, `PackDrawerView.COLORS`). Neue Tabelle `DICE_PACK_TINTS` mit den vier Sorten (normal = neutraler Stahlton für Naht/Hover). Das Band trägt Hover/Flare (`_edge_material`).
- **Symbol auf dem Band** (oben groß auf dem Deckel, klein auf dem Rücken): Seele = Raute (◆, wie der Essenz-Chip), Material = Kachel (■), Runen = eine Rune als Strich-Figur (z. B. ᛉ aus Boxen). Dunkel ins Band eingelassen bzw. hell erhaben – Agent wählt nach Sichtprobe, Hauptsache auf ~30 px lesbar.
- **Güte = ECKKAPPEN**: Standard keine; Edel vier Silber-Kappen; Royal vier Gold-Kappen mit je einem kleinen violetten Stein (leise pulsierend). Die Kappen umgreifen die Ecken so, daß sie von oben UND von der Seite zu sehen sind.
- Die Leuchtnaht wird neutral (Stahlton), die Royal-Puls-Naht entfällt. Der Rücken-Marker (`add_spine`) wird durch das Band ersetzt: Normal behält einen schlichten neutralen Rücken.
- **Keine zwei Teile teilen eine Fläche** (Band über dem Lack, Kappen über Band und Saum) – ein Test wie `test_no_two_cassette_parts_share_a_face` für die Schatulle.
- Der aktuelle, noch nicht committete Lack der Schatulle (heller, matter, `CASE_GLOW_ENERGY` 0,12, Narbung `case_grain`) bleibt die Grundlage.

## D. Lager, Laden, Wetten
- Lager-Rinne: Teilung folgt weiter der dicksten Hülle; die Rinnen-Höhe muß die BREITESTE Schatulle (Riesig) quer fassen – `PackStoreView`/`_pack_spine_px` entsprechend (8 Plätze je Rinne bleiben, Spieler-Entscheid von heute, noch nicht committet).
- Laden: Würfel-Bucht zeigt die neuen Sorten/Größen; Preisschilder über `DicePack.price_of`.
- Nebenwetten: Würfel-Paket-Gewinne aus den neuen Sorten/Größen.

## E. Tests und Doku
- Tests: Sorten-Gewichte und -Namen, keine Klein-Würfelpakete, Garantien je Sorte (Seele, ≥2 Material-Seiten, ≥1 Rune), Runen-Chance mit Glück, Güte-Glück +0/+6/+12 wirkt auf die Ketten (deterministisch über RNG/Erwartungswerte), Breite wächst mit der Größe, Banderole/Symbol nur bei den drei Typen, Eckkappen je Güte, keine geteilte Fläche. Gestorbene Tests (Güte je Würfel, Enthüllung, Augen) umschreiben oder löschen, nie auskommentieren.
- Doku: Root-`CLAUDE.md` (PAKET-AUSWAHL-Absatz: Würfel-Pakete, Grundzahl, Güte; EINE-Größe-Regel um die benannte Ausnahme ergänzen), `scripts/data/CLAUDE.md`, `scripts/core/CLAUDE.md`, `scripts/ui/CLAUDE.md` (Bühne ohne Enthüllung), `scripts/table/CLAUDE.md` (Schatulle), Abschnitt „Umsetzung“ am Ende dieser Datei mit gemessenen Maßen. Obsidian-Seite 46 (`E:\Obsidian Vault\Games\Fumble\46 Würfel-Pakete - Größe, Güte und das Öffnen.md`) um einen kurzen Nachtrag mit den neuen Regeln ergänzen.

## Umsetzung (2026-11-14)
Umgesetzt wie oben, mit diesen Entscheidungen der Session:
- **Daten:** `DicePack` kennt `SORT_NORMAL/SOUL/MATERIAL/RUNE`, `SIZES` (Normal/Groß/Riesig), `QUALITY_LUCK` [0, 6, 12] (`quality_luck`) und `SHOP_SIZE_WEIGHTS` [0, 40, 22, 8]; `expected_picks` ist mit der Preisformel gestorben (die Preise sind die feste Vorgabe-Tabelle). `GameRun.pack_luck(pack)` = `effective_luck()` + Güte-Glück trägt Würfelzahl, Wahlen, Seele und Rune; `shop_tier()` bleibt unberührt. `DiceOffer.roll_pack_die` zieht jede Vorlage, Material wie im Laden (`roll_refinements`), Rune `pack_rune_chance` (15 % + 1,5 je Glück, Deckel 50 %, `_add_rune` auf eine freie Seite). `SideBet.DICE_PACK_MIN` 12 → 14 (das billigste Würfel-Paket), `reward_dice_pair` sucht nur noch in `DicePack.SIZES`.
- **Öffnung:** die Netze gehen mit der Aufstellung auf (`show_lineup` → `reveal_net`), `play_reveal` heißt `play_reel` und startet direkt die Walze; Stufen jetzt `LAUNCH/LINEUP/REEL/PICK` (0–3). `CaseShow.play_reveal_tick`/`play_lock` sind mit ihren Signalen gestorben.
- **Breite:** je Größe ein eigenes Blender-Modell (`dice_case.glb`, `dice_case_large.glb`, `dice_case_huge.glb`) statt Godot-Skalierung — Ecken, Wände, Schließe und Scharnier bleiben unverzerrt; `CardPackView.CASE_WIDTHS` spiegelt die Skript-Tabelle.
- **Banderole und Kappen** sind im Blender-Skript als Schalen über die Rundung gebaut (Haut minus Gehäuse, Band 0,012 stark und 0,3 breit, Kappen 0,02 stark über 0,2 × 0,19 je Ecke), damit sie der Wölbung folgen; das Band läuft LÄNGS (Deckel, Rücken, Boden, Fuß), denn nur so liegt es in der Rinne als Farbblock auf dem Rücken (der Rücken ist die Kopfseite +Y). Die Schließe sitzt dabei 0,004 tiefer, sonst teilte ihre Oberkante die Ebene des Bodens.
- **Symbol:** dunkel und eine Spur erhaben (`SYMBOL_PROUD` 0,006 Roh-Maß), aus Boxen in Godot gebaut — Seele eine Raute, Material eine 2×2-Kachel (eine einzelne Kachel las zu ähnlich wie die gedrehte Raute), Runen die Algiz-Rune (ᛉ). `SYMBOL_TURN` stellt „oben“ quer zur Banderole: in Laden und Rinne steht die Rune aufrecht (Sichtprobe).
- **Silber** der Edel-Kappen mit `SILVER_ENERGY` 0,55 (bei 0,3 las es in der Rinne wie Stahl).
- **Lager-Rinnen:** ungleich hoch statt gleich — jede so hoch, wie ihr breitestes Paket quer mißt (`PackStoreView.lane_across`), `EDGE_SHARE` 0,06 → 0,03, damit alle drei samt Köpfen in die Tray-Höhe 570 passen.
- **Laden-Bucht:** `ShopController.bay_height()` = größtes aus Würfel, Stellplatz und `dice_case_across_px × CASE_ROOM` 1,06 (gemeldet von scene_root, ui/ kennt `CardPackView` nicht); `VitrineView.case_reach()` weitet das Loch der Schale.

**Gemessen** (1280 × 720, 37,5 px/Welt):
- Schatulle quer (Roh-Maß ohne Kappen): Normal 1,123, Groß 1,292, Riesig 1,460 → im Anzeigemaß (× 3,2) 3,59 / 4,13 / 4,67 Welt; breiteste samt Kappen 180,0 Display-px.
- Lager: Fassung **540,4 × 570** Display-px (x 3719,6–4260,0), Rinnen 528,3 × **143,9** (Karten) / **189,2** (Würfel) / **143,9** (Module), Rücken 58,1 × 134,8, Teilung 65,0.
- Laden-Bucht: 1004 × **190,8** Display-px (vorher 149).
- Öffnungs-Fläche unverändert **1480,4 × 754,9** (x 3593,7–5074,1); die Riesig-Schatulle steht ganz in der linken Spalte und wird über `PIT_CASE` eingezogen (Sichtprobe).

Sichtproben: `C:/Users/trist/AppData/Local/Temp/claude/fc353d6d9511eec6/d3aa7fd5-48c2-4650-9bdd-5b29b353b3dd/scratchpad/u_*.png` (Lager CHIPS, Rinne nah, Präsentation Royal, Öffnung Flug/Wurf/Aufstellung/Wahl/Einzug, Laden).

## Nachtrag (2026-11-14, Spieler-Wunsch): eine Größe, die Würfelseite sagt sie
- Alle Schatullen sind wieder gleich breit (EIN Modell `dice_case.glb`); `dice_case_large/huge.glb`, `CASE_WIDTHS`, `case_width_share`, `case_across` und `width_share` sind gestorben.
- Die Größe zeigt eine WÜRFELSEITE neben der Banderole: Normal 1, Groß 3, Riesig 6 Augen (`CardPackView.CASE_PIPS`), groß auf dem Deckel, klein auf dem Rücken. Die Rücken-Marke der normalen Schatulle ist dafür gestorben.
- Gemessen (1280 × 720): Schatulle quer 139,6 Display-px, Würfel-Rinne 162,2, Laden-Bucht 150.
