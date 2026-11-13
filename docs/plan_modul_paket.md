# Plan: Modul-Pakete im ESD-Beutel (2026-11-13)

Spieler-Wunsch: eine DRITTE Paket-Art neben Karten-Paket (Daten-Kassette) und Würfel-Paket (Schatulle) — das MODUL-PAKET, ein silberner ESD-Abschirmbeutel (Mockup B: Siegelnaht oben mit Quetschrillen, darunter ein Streifen in der Farbe der Paket-Seltenheit, schwarzes Etikett mit gelbem Warndreieck und „ESD“, Reißkerbe an der rechten Kante, goldene Kontakt-Quadrate auf dem Etikett = Grund-Optionenzahl). Baut auf der Paket-Auswahl (`PackChoice`) und dem Paket-Lager (`docs/plan_paket_lager.md`) auf.

## Entscheidungen (Spieler)
1. **Laden**: der Einzel-Modul-Platz in der Würfel-Zeile (`SHOP_PART_SLOTS` 1) wird zum MODUL-PAKET-Platz — wie die Einzelwürfel den Würfel-Paketen gewichen sind. Der Schwarzmarkt verkauft weiter EINZELNE (×-)Module, unverändert.
2. **Die Siegelnaht = SELTENHEITS-STUFE des Pakets** (Analogon zur Güte der Würfel-Pakete): Gewöhnlich / Selten / Episch / Legendär (Farben aus `ComboPart.RARITY_COLORS`). Die Stufe verschiebt die Gewichte der Modul-Seltenheiten der Optionen nach oben und hebt den Preis; im Laden mit `progress_tier()` wachsende Chance auf höhere Stufen. Steht beim Kauf fest, wie Größe.
3. **Zu wenig freie Steckplätze: erlaubt, TAUSCH**. Ein Modul-Paket ist immer kauf- und öffenbar (`parts_room()` sperrt es NICHT). Gewählte Module gehen in `pending_parts` und werden wie gewohnt eingebaut; ist kein Steckplatz frei, ERSETZT der Einbau ein steckendes Modul, und das verdrängte ist VERLOREN (nicht zurück nach `pending_parts`, sonst kreist es ewig). Der Einbau-Rahmen sagt das vor dem Klick deutlich (Hinweis „ersetzt X — X geht verloren“), ein freier Platz bleibt der bevorzugte Weg. Gilt nur für Module aus Paketen; der Einzelkauf im Schwarzmarkt behält seine `parts_room`-Sperre (Agent prüft, ob die Regel einfacher für alle Wege gilt, und meldet es — nicht eigenmächtig vereinheitlichen).
4. **Lager**: eine DRITTE Grube rechts neben der Würfel-Grube, gleiche Bauart (je Art `STORE_CAPACITY` 8, 2 × 2 sichtbar plus zweite Lage, `store_slot` behalten bis zum Öffnen). Das Lager wird so breit wie nötig, die Anzeige wächst um genau das Nötige nach rechts (`TableScreen.EXTRA_RIGHT`; Muster wie in der Lager-Welle). Öffnungs-Fläche und Chip-Station prüfen, ob sie mitwandern müssen.

## Zahlen (Vorschlag, wie Karten-Pakete)
- Größen Klein / Normal / Groß / Riesig: Optionen 3 / 4 / 5 / 5, Wahlen 1 / 1 / 2 / 2, Glückswurf +1 und Riesig-Hauptgewinn wie `CardPack.roll_picks` (wiederverwenden, nicht kopieren).
- Optionen: Laden-Module (`ComboPart.pool(false)`), keine Dubletten innerhalb eines Pakets, Seltenheits-Gewichte nach Paket-Stufe verschoben. Preis: Grundpreis je Größe × Stufen-Faktor (analog `DicePack.QUALITY_PRICE_FACTORS`), dann wie alle Ladenpreise über `shop_price`.
- Neu mischen 1 ⚡ einmal je Paket, wie die anderen.

## Datenmodell
- Neues `scripts/data/module_pack.gd` (`class_name ModulePack`, Resource wie `DicePack`): `size`, `grade` (Seltenheits-Stufe), `display_name`, `info_body`, `price_of`, Gewichts-Tabelle. Ids als `const`-Strings.
- `PackChoice.KIND_MODULES`; Optionen sind `ComboPart`-Instanzen (je eigene Instanz, `instantiate()` beim Bestätigen).
- `GameRun.stored_module_packs` + `purchase_module_pack`, `open_stored_pack` erkennt die Art, `confirm_pack_choice` legt gewählte Module nach `pending_parts`. Lauf-Reset leert alles.
- Nebenwetten-Gewinne: nur wenn es eine natürliche Stelle gibt, Modul-Pakete als Gewinn-Ware ergänzen; sonst weglassen und melden.

## Körper und Öffnung
- `ModulePackBody` (oder eine Art in `CardPackView`): der ESD-BEUTEL auf dem EINEN Paket-Grundriß (EINE Größe je Ding); die Paketgröße wächst nur in der DICKE/Wölbung. Prozedural gebaut (flache, leicht gewölbte Hülle, metallisch-silber mit leichtem Rosa-Stich, gequetschte Siegelnaht mit Rillen, Seltenheitsstreifen emissiv gedämpft, Etikett mit gelbem Warndreieck und „ESD“, goldene Kontakt-Quadrate = Grund-Optionen, Reißkerbe). Kein Blender-Modell nötig.
- Kauf: Flug aus dem Laden-Platz in die Modul-Grube (`_fly_into_store`-Muster). Laden-Auslage zeigt den Beutel wie die anderen Pakete.
- Öffnen auf der Öffnungs-Fläche (`PackChoiceView`): der Beutel fliegt an den Kopf der linken Spalte, REISST an der Kerbe auf (die obere Ecke klappt/fällt ab), und die Module fallen einzeln als `ComboPartBody` (EINE Größe) auf ihre Plätze der Aufstellung; Seltenheit der Option als Saum, Tooltip/Hinweis wie im Laden (`part_foot_text`-Quelle wiederverwenden). Bestätigt fliegen die Gewählten Richtung Kombinations-Chips/Einbau, die übrigen verfallen, der Tisch zieht den Beutel ein (Hebebühne wie `PIT_CASE`). Endzustand zuerst, ein Klick springt ans Ende, `_settle_pack_openings` räumt auch das.
- Danach greift der bestehende Einbau-Fluß für `pending_parts` (mit der Tausch-Regel aus Entscheidung 3).

## Rückbau
Der Einzel-Modul-Platz des normalen Ladens samt seiner nur dafür gebrauchten Pfade (`roll_shop_part`/`purchase_part`-Aufrufer im Laden, `part_options`/`part_bought` in `ShopController`, `part_purchased`-Flug) — löschen, soweit der Schwarzmarkt sie nicht braucht. Tests umschreiben, nicht auskommentieren.

## Docs und Tests
- Root-`CLAUDE.md` (PAKET-AUSWAHL, Lager-Layout, UI-Wort vs. Code-Wort: „Modul-Paket“/`ModulePack`, „Beutel“), `scripts/{core,data,table,ui}/CLAUDE.md`, Obsidian: neue Seite im Fumble-Ordner (`E:\Obsidian Vault\Games\Fumble\`, nächste freie Nummer).
- Tests: ModulePack-Zahlen und Gewichte, Kauf/Lager/Kapazität/Öffnen/Bestätigen nach `pending_parts`, Tausch-Einbau verliert das verdrängte, Laden-Zeile mit Modul-Paket-Platz, Lager-Fassung mit drei Gruben, Öffnungs-Fläche mit Modul-Optionen.

## Umsetzung (2026-11-13)
Umgesetzt wie oben, mit diesen Abweichungen:
- **Kapazität 12 / 2 × 3** statt 8 / 2 × 2: die Lager-Welle stand beim Bau schon auf dem dritten Nachtrag (12 je Art, zwei Lagen zu 2 × 3); die Modul-Grube teilt genau diese Bauart.
- **Layout gemessen** (1280 × 720): Lager 1354,6 × 570 px (x 99,2–135,3 Welt), drei Gruben zu je 439 × 515 px; `EXTRA_RIGHT` 414 px (11,04 Welt), `RESOLUTION` 5094 × 3180 — jetzt stellt das Lager die Breite. Öffnungs-Fläche unverändert 1005 × 446 px direkt darunter; die Chip-Station rahmt Tray und Lager aus derselben Rechnung.
- **Nebenwetten**: kein Modul-Paket-Gewinn — die Wetten zahlen weiter EINZELNE Module (`Payout.PART`); ein Paket-Gewinn bräuchte eigene Körper an Tresen und Auszahlungs-Seite.
- **Tausch-Regel**: ein Paket-Modul verdrängt auf einem belegten Platz IMMER (auch wenn noch Platz frei wäre), und das Verdrängte ist verloren; der Hinweis nennt es vor dem Klick. Nicht vereinheitlicht: Schwarzmarkt und Wett-Module behalten Sperre bzw. Rückweg in die Schlange (sie kommen nie ohne freien Platz an, eine Vereinheitlichung wäre möglich, ist aber Spieler-Sache).
- Laden-Module kennen keine legendären Teile (alle legendären sind Schwarzmarkt-Ware): die Stufe Legendär zieht dort vor allem die epischen.
