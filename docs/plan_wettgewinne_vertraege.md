# Plan: Nebenwetten-Gewinnwert + neue Vertragsklauseln (2026-11-10)

Spieler-Entscheid, Spec = Obsidian-Seite `E:/Obsidian Vault/Games/Fumble/42 Nebenwetten-Gewinne und neue Verträge.md` (lesen!). Ladenpreise seit Commit 155dadb (Seite 41).

## Teil A — Nebenwetten zahlen einen GEWINNWERT in einer gewürfelten Ware

### A1. Wert je Wette
`Gewinnwert = Einsatzwert × Quote`, bei Waren (alles außer Geld) **× 1,25**, gerundet auf ganze $.

- Quoten: `EASY` ×2, `MEDIUM` ×2,5, `HARD` ×3 (Spieler-Entscheid 2026-11-10).
- Einsatzwert: Geld wie gedruckt; `Stake.PACKS` = Summe der Ladenpreise der GENANNTEN Pakete (Sorte+Größe stehen nach `_name_stake_packs` fest, `Pack.tiered(Pack.by_type(t), tier).price`); `MONEY_PER_HAND` ×4; `MONEY_PER_DIE` ×10; `ENERGY` ×10 $/⚡.
- Der Wert wird aus dem UNBESTEUERTEN Grund-Einsatz gerechnet (Wettsteuer ändert ihn nicht). Der Quotenbonus (`side_bet_payout_factor`) und die neue Klausel Hoher Tisch multiplizieren den WERT - auch Einzelstücke werden dadurch besser (größere Karte, seltenere Seele, mehr Karten).

Klassen je Vorlage (ersetzt `payout`/`reward`/`payout_money`/`payout_energy` der Vorlagen; Feld z. B. `"odds": ODDS_MEDIUM`):

| EASY | MEDIUM | HARD |
| --- | --- | --- |
| two_pair, table_fee, dice_toll | full_house, big_hand, economist, jackpot, pawn, clean_run, tinkerer, prototype, quick_start, overclocker, collateral, connoisseur, upper_class, variety, comeback, no_scraps, feedback_loop, patent | large_straight, chain_reaction, high_roller, resupply, efficiency, small_fry, deep_energy, blank_check, collector, whale, shipment, full_grip, all_in_hand, circuit_contract, clean_room |

**Ausnahme:** `circuit_contract` (Pointer) und `clean_room` (Veredelung) behalten ihren FESTEN Sonderposten (`Payout.SPECIAL`) und würfeln nichts.

### A2. Die Ware - beim Auslegen gewürfelt (`_from_template`), danach fest
Nur Arten, deren Mindestwert ≤ Wert (Geldwert vor dem ×1,25 bei Geld; für Waren mit dem ×1,25-Wert prüfen):

| Art | Gewicht | Ab Wert | Menge |
| --- | --- | --- | --- |
| Geld | 20 | – | Wert in $ (ohne ×1,25) |
| Zahlen-Karten | 14 | $4 | größte Größe, deren Preis ≤ Wert; Anzahl = floor(Wert / Preis), höchstens 4 |
| Material-Karten | 10 | $5 | dito |
| Runen-Karten | 8 | $6 | dito |
| Multiplikator-Karten | 6 | $8 | dito (Multiplikator-Netz wie im Laden, Preis `MULTIPLIER_PRICE` × Größenfaktor) |
| Würfel | 12 | $8 | EIN Laden-Würfel (`DiceOffer`-Vorlage zufällig); Seele nach Wert: < $12 keine oder gewöhnlich (wie Laden-Wurf, aber höchstens gewöhnlich), ab $12 selten, ab $20 episch, ab $32 legendär (Unikat-Regeln wie `roll_essence`, eine Seltenheit tiefer, falls der Topf leer ist) |
| Modul | 10 | $5 | EIN Laden-Modul mit Preis ≤ Wert (`ComboPart.pool(false)`) |
| Energie | 8 | $8 | floor(Wert / 8) ⚡ (Überlauf zahlt bar wie heute) |
| Katalysator | 5 | $8 | Kühlrippe ($8), Kältebad ($14) oder Treibladung ($14), nur was ≤ Wert |
| Operator | 4 | $11 | Spiegel ($11), Verdoppler ($12), Sammler ($14), nur was ≤ Wert |
| Sonderposten | 3 | $18 | `Pack.roll_special_pack()` |

Reparatur-Karte und Rohling NIE (Schwarzmarkt-Ware).

### A3. Auszahlung und Anzeige
- Alle Karten-Arten (inkl. Katalysator, Operator, Multiplikator, Sonderposten) laufen über `reward_cards` → `grant_pack`, Körper = Kassette ihrer Sorte (`_bet_price_spec`), wie heute `PACKS`.
- **Würfel**: neuer `Payout.DIE`. Der Würfel wird beim Auslegen gewürfelt und gemerkt (der Knopf nennt ihn: „1 Kraftwürfel“ bzw. mit Seele „1 Kraftwürfel · Neon“). Gewinn = Weg des Ladenkaufs in `pending_dice` → ZWANG zum sofortigen Einsetzen (siehe *DER ZWANG* in CLAUDE.md). PRÜFEN, ob der Zwang in der Auszahlungs-Phase greift bzw. wann er aufzieht; er darf die Kassieren-Seite nicht kaputt machen. Körper auf dem Tresen: wie das Modul eine Marke (`"body": "token", "text": "WÜRFEL"`), sofern ein echter Würfelkörper dort nicht billig zu haben ist.
- `reward_label`, `SideBetPanel` (Zeile ~256), alle `match bet.payout_kind` in `scene_root` (~7250, ~7437, ~13600, ~13876) mitziehen.
- `pays_cards()` auf alle Karten-Arten.

## Teil B — neue Klauseln (Texte genau so, Stil Seite 39)

Alle Bonus-Klauseln sind Verstärker. Jede Wirkung als `GameRun`-Abfrage über `_clause_active` (nie stiller Zweig in scene_root). Jede neue Bonus-Klausel mit Zahl bekommt ihre Winkeladvokat-Fassung in `DealClause.text_for` und wirkt mit `deal_bonus_factor()`. Tags so, dass die Paarungsregel (kein geteiltes Tag) sinnvoll bleibt.

| id | Name | Art/Stufe | Scope | Text | Tags | Wirkung |
| --- | --- | --- | --- | --- | --- | --- |
| lucky_day | Glückstag | Bonus T1 | ROUND | Laden würfelt mit Glück +3. | shop, glück | neue `shop_tier()` = Fortschrittsstufe aus `luck + 3·factor`; ALLE Laden-Auslage-Würfe (Charm-Seltenheit, Multiplikator-Chance, Sonderposten-Chance, Würfel-Augen) nehmen sie statt `progress_tier()` |
| bulk_order | Großauftrag | Bonus T1 | ROUND | Karten im Laden öfter Groß und Kolossal. | shop | Größen-Gewichte im Laden 30/45/25 statt 60/30/10 |
| connoisseur_eye | Kennerblick | Bonus T2 | ROUND | Seltene und legendäre Charms doppelt so oft. | shop | Laden-Ziehgewicht rare/legendary ×2 |
| soul_market | Seelenmarkt | Bonus T1 | ROUND | Laden-Würfel tragen immer eine Seele. | shop | Laden-Würfel: Seelen-Chance 1,0, Gewicht selten/episch/legendär ×2 |
| full_vitrine | Volle Vitrine | Bonus T2 | ROUND | Laden: +1 Charm, +1 Würfel, +1 Karte. | shop | `shop_charm_slots/dice_slots/pack_slots` +1 — die Vitrine muss das tragen (Stellplätze, Schlitze); prüfen und notfalls melden |
| free_flip | Freies Blättern | Bonus T1 | ROUND | Blättern im Laden gratis. | shop | `shop_flip_fee_factor` 0 |
| buyback | Rückkaufrecht | Bonus T1 | ROUND | Charms verkaufen zum vollen Preis. | geld | Verkaufswert = `charm.price` |
| math_week | Rechenwoche | Bonus T2 | ROUND | Multiplikator-Karten dreimal so oft. | shop | `shop_multiplier_chance` ×3 (Deckel bleibt) |
| regular_customer | Stammkunde | Bonus T3 | BLOCK | Ladenpreise −15 % bis zur Boss-Runde. | shop | Faktor 0,85 in `shop_price_factor`; erste Klausel mit `Scope.BLOCK` - `_scope_reaches` kennt BLOCK schon, `DealTokenRow` zeigt es; core/CLAUDE.md-Satz „no clause carries BLOCK“ anpassen |
| special_delivery | Sonderlieferung | Bonus T3 | ROUND | Laden führt sicher einen Sonderposten. | shop | `shop_special_chance` = 1, auch unter Stufe 8 |
| back_room_contact | Hinterzimmer-Kontakt | Bonus T2 | ROUND | Schwarzmarkt: −1 ⚡ je Ware, Neuwurf gratis. | shop | `secret_offer_price` −1 (min 1), `secret_reroll_cost` 0 |
| loaded_reels | Gezinkte Walzen | Bonus T2 | ROUND | Automaten: kein Fumble-Feld. | automat | `SlotPrize.Kind.FUMBLE` fällt aus dem Walzen-Wurf |
| reinsurance | Rückversicherung | Bonus T1 | ROUND | Verlorene Nebenwette: Einsatz zurück. | nebenwette | beim Verlieren: Geld/⚡/gezahlte Steuer zurück, geopferte Karten zurück ins Magazin (dieselben Pack-Objekte merken) |
| wide_offer | Breites Angebot | Bonus T1 | ROUND | +1 Nebenwette in der Auslage. | nebenwette | `SideBetPanel.OFFER_COUNT` ist heute const 3 und bemisst Fenster + Schächte. Nur umsetzen, wenn ein 4. Platz sauber geht (Fenster wächst, Schächte, Tresen); sonst NICHT hacken, sondern im Bericht melden |
| high_table | Hoher Tisch | Bonus T3 | ROUND | Nebenwetten: Einsatz und Gewinn ×1,5. | nebenwette | Einsatz ×1,5 (aufrunden), Gewinnwert ×1,5 |
| cold_press | Kaltpressung | Bonus T2 | ROUND | Prägen erhitzt nicht. | ladung | das erzwungene +1 Ladung beim Prägen entfällt |
| big_storage | Großer Speicher | Bonus T2 | INSTANT | Börse dauerhaft +5 ⚡ Platz. | energie | neue Lauf-Variable, `energy_cap_rows()` +1 je Unterschrift (Deckel `ENERGY_CAP_LIMIT` bleibt); `new_run` setzt zurück |
| empty_shelves | Leere Regale | Malus T1 | ROUND | Laden: −1 Karte, −1 Würfel. | shop | Slots −1 (min 1) |
| shelf_warmer | Ladenhüter | Malus T2 | ROUND | Laden führt nur gewöhnliche Charms. | shop | Charm-Topf nur common (Rückfall auf vollen Topf, wenn leer) |
| soulless | Seelenlos | Malus T1 | ROUND | Laden-Würfel ohne Seele. | shop | Seelen-Chance 0 |
| flip_surcharge | Blätter-Aufschlag | Malus T1 | ROUND | Blättern kostet doppelt. | shop | Blätter-Gebühr ×2 |

WICHTIG: Die Laden-Auslage wird beim Öffnen gewürfelt (`ShopController._roll_spread` o. ä.) - die Runden-Klauseln gelten im Laden DERSELBEN Runde (`_scope_reaches`); prüfen, dass eine im Laden schon gewürfelte Seite nicht nachträglich anders wird.

## Tests
- Neue Unit-Tests: Wert-Rechnung je Klasse und Einsatzart, Waren-Wahl respektiert Mindestwerte, Karten-Mengen-Regel, Würfel-Seele nach Wert, jede neue Klausel wirkt (eine Abfrage je Klausel), Winkeladvokat-Fassungen.
- Alte Tests, die feste Gewinne erwarten (`test_side_bet*`, Tresen-/Auszahlungs-Integrationstests, `test_deal_clause*`, Katalog-Zählungen), anpassen statt löschen, wo der Sinn bleibt.

## Doku
`scripts/core/CLAUDE.md` (Nebenwetten, Verträge/BLOCK), `scripts/ui/CLAUDE.md` wo der Tresen/Wett-Panel beschrieben ist. Kurz, deutsch, nach den Kommentar-Regeln in CLAUDE.md.
