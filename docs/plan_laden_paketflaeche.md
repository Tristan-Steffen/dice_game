# Plan: EINE Paket-Fläche im Laden (2026-11-16)

Spieler-Wunsch: Würfel-Bucht (2 Würfel-Pakete + 1 Modul-Paket) und Gravuren-Zeile (3 Karten-Pakete,
ggf. Sonder-Karte) verschmelzen zu EINER Fläche, auf der jedes Paket an jedem Platz liegen kann.
Mit Glück liegen 6 Würfel-, 6 Karten- oder sogar 6 Modul-Pakete im Laden.

## Entscheide (Spieler, 2026-11-16)
- **6 Plätze**, jeder würfelt seine Art UNABHÄNGIG mit dem heutigen Mittel **3 : 2 : 1**
  (Karten 1/2, Würfel 1/3, Module 1/6). Keine Garantie je Art.
- **Layout 2 Reihen × 3 Plätze** auf dem bestehenden Spaltenraster (`COLUMNS` 3), EINE Überschrift
  „PAKETE“. Jeder Platz ist für das größte Paket bemessen; Name + Preis ÜBER dem Paket, Auskunft
  darunter — die heutige Würfel-Bucht-Grammatik, für alle drei Arten.
- **Sonder-Karte** (ab Stufe 8 bzw. Klausel `SPECIAL_DELIVERY`, Chance unverändert
  `shop_special_chance()`): ersetzt, wenn sie fällt, einen **zufälligen** der 6 Plätze.

## Ziel-Modell
- `MenuSpread`: EINE Liste `packs: Array[Resource]` (CardPack | DicePack | ModulePack | Pack-Sonder),
  `pack_prices`, `pack_bought`, je Platz index-treu (verkauft = Lücke). Die drei getrennten Listen
  (`engraving_packs`, `single_dice`, `module_packs`, `single_specials` samt Preis/Bought) gehen darin auf.
- EIN Kaufweg (Gattung + Index → nur noch Platz-Index), EIN Kauf-Signal an scene_root
  (z. B. `shop_pack_purchased(seat)`), das je Art das richtige tut (Lager-Flug der Hülle bzw.
  Sonder-Karte als Licht ins Magazin wie heute `pack_purchased`).
- `GameRun`: `SHOP_PACK_PLACES` 6 und die Arten-Gewichte als Konstanten (eine Quelle);
  `shop_dice_slots`/`shop_pack_slots`/`shop_module_pack_slots` fallen weg oder werden zu EINER Frage.
  Klauseln, die heute Plätze leeren (`shop_packs_offered`, `shop_dice_offered` — „Leere Regale“),
  wirken weiter sinnvoll auf die eine Fläche (hintere Plätze stehen leer wie verkauft).
  Preise unverändert je Art (`_pack_price`, `_dice_pack_price`, `module_pack_shop_price`).
- `ware_info`/`ware_tint`/Auskunfts-Band sprechen für jede Art (Karten-Paket bekommt dieselbe Block-
  Grammatik wie die Würfel-Pakete: Name in Sortenfarbe, Preis, `info_body`).

## Körper (scene_root)
Heute zwei Maschinen: die Kassetten-Schlitzreihe (`_write_slit_cells`, je Platz eine Sektion,
Hüllen über `_spawn_slit_ware` → `_spawn_hull`) und die Laden-`VitrineView` (Schatullen, Beutel,
`die_spots`, Netz-Blöcke). Es soll EINE Maschine übrig bleiben, die jede Hülle auf jedem der 6 Plätze
stellt, hebt (Hover), abräumt (Blättern/Schließen) und beim Kauf ins Lager fliegt (`_fly_into_store`).
Welche der beiden verallgemeinert wird, entscheidet der Umsetzer nach Lektüre — Hinweis: alle drei
Hüllen sind `CardPackView`, und `_spawn_hull` baut schon Karten-Schachteln; der Schwarzmarkt nutzt
`VitrineView` weiter und darf nicht brechen. Die tote Maschine wird restlos entfernt, nicht stillgelegt.
Invarianten: Endzustand zuerst, EIN idempotenter Schreiber je Körper-Ort, ui/ faßt keinen Körper an
(der Laden MELDET Platz-Rechtecke/Anker in Display-Pixeln), EINE Größe je Ding.

## Fertig heißt
- Laden zeigt 6 gemischte Plätze in 2 × 3, Kauf/Hover/Blättern/Sperre/Neu-Öffnen/Schließen funktionieren
  für jede Art; voller Lager-Platz sperrt nur die betroffene Art („LAGER VOLL“).
- Tests angepaßt/neu (u. a. Gewichte, Sonder-Karte ersetzt zufälligen Platz, Kauf je Art), Suite grün,
  Boot ohne Fehler, eine Sichtprobe der Ladenseite.
- CLAUDE.md-Abschnitte nachgezogen (Wurzel: PAKET-AUSWAHL-Satz „zwei Würfel-Paket-Plätze“;
  `scripts/ui/CLAUDE.md`: DREI REGALE, PAKET-PLÄTZE, MODUL-PAKET im Laden; `scripts/table/CLAUDE.md`:
  *Die DREI REGALE* unter *Die VITRINE*).
