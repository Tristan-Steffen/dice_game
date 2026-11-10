# Plan: Karten-Pakete im Laden (2026-11-10)

Spieler-Entscheid, Spec = Obsidian-Seite `E:/Obsidian Vault/Games/Fumble/44 Karten-Pakete - Plan.md` (lesen, Abschnitte 1–7 gelten; Abschnitt 8 sind nur Ideen, NICHT bauen).

## Kern

Der normale Laden verkauft keine Einzelkarten mehr, sondern **versiegelte, undurchsichtige PAKETE**. Ein Paket öffnet sich **sofort nach dem Kauf**, der Spieler bekommt **alle** Karten darin (keine Auswahl, kein Verschrotten). Schwarzmarkt, Automaten, Boss-Prämie und die Karten-Charms bleiben bei Einzelkarten. Nebenwetten zahlen weiter Einzelkarten UND bekommen Pakete als zusätzliche Gewinn-Art.

## Wörter (UI vs. Code)

- Einzelne Data-Card: im Spiel **„Karte“** („Zahlen-Karte“, „Große Material-Karte“, Mehrzahl „Karten“); im Code bleibt sie `Pack`.
- Neuer Behälter: im Spiel **„Paket“** („Material-Paket“, „Großes Misch-Paket“); im Code `CardPack` (`scripts/data/card_pack.gd`, `class_name CardPack`, danach einmal `--import`).
- Alle Spieltexte, die heute eine Einzelkarte „Paket“ nennen, umstellen: `Pack.TYPE_NAMES`, `MULTIPLIER_NAME`, `amount_phrase`/`named_phrase`, Wett-Knöpfe, Hinweiszeilen, Charm-Texte und Lexikon (grep nach `Paket`). Schnäppchenjäger („Pakete kosten 30 % weniger“) und Kleingedrucktes („Paket-Kauf: 20 % Chance auf volle Erstattung“) wirken künftig auf die neuen Pakete und behalten ihre Texte. Andere Charms, die Einzelkarten liefern (Füllhorn, Schmuckkästchen …), sagen danach „Karte“. Neuer Lexikon-Eintrag „Paket“, „Karte“ prüfen.
- CLAUDE.md, Abschnitt *UI-Wort vs. Code-Wort*: `Karte/Pack`, `Paket/CardPack` ergänzen.

## Daten (`CardPack`)

- Sorten: `NUMBER` (Zahlen; jede Karte mit `shop_multiplier_chance` als Multiplikator-Karte), `MATERIAL`, `RUNE`, `SPECIAL` (Sonder: Sonderposten über `Pack.roll_special_pack`, Kühlrippe, Kältebad, Treibladung, Operatoren, Multiplikator-Karten), `MIXED` (Misch: jede Karte einzeln nach Regal-Gewicht aus Zahlen/Material/Runen, mit 15 % Chance auf eine Sonder-Karte). Nie Reparatur-Karte, nie Rohling.
- Größen: `SMALL` „Klein“ 2 Karten, Kartengrößen 70/25/5; `NORMAL` „Normal“ 3 Karten, 60/30/10; `LARGE` „Groß“ 4 Karten, 45/40/15, mindestens eine Große; `HUGE` „Riesig“ 5 Karten, 35/45/20, mindestens eine Kolossale. (Kartengrößen nur bei Karten, die eine tragen — `Pack.tierable`.) Sonder-Pakete nur Klein und Normal.
- Kein doppeltes Netz in einem Paket.
- Preis = erwarteter Inhaltswert zu Ladenpreisen × 0,8, gerundet. Richtwerte (Seite 44): Zahlen 10/17/27/38, Material 13/22/35/49, Runen 15/26/41/57, Sonder 22/34, Misch 12/20/31/44. Als Tabelle festschreiben, nicht zur Laufzeit schätzen; ein Test prüft, dass sie zur Formel passt (Toleranz ±2).
- Der INHALT wird beim KAUF gewürfelt (undurchsichtig, also muss vorher nichts feststehen). `Großauftrag` (Klausel) hebt im Paket die Kartengrößen wie heute im Laden; `Glückstag` über `shop_tier()` wie bisher.

## Laden

- Die Karten-Plätze der Reihe (`ShopController.slit_seats`, `engraving_packs`, `KIND_ENGRAVING_PACK`) werden **Paket-Plätze**: Sorte gewichtet (Zahlen 6, Material 3, Runen 2 wie `Pack.SHELF_WEIGHTS`, Misch so, dass ~25 % der Plätze Misch sind), Größe gewichtet Klein 30 / Normal 40 / Groß 22 / Riesig 8.
- Der Sonderposten-Platz (`single_specials`, ab Stufe 8 bzw. `Sonderlieferung`) wird ein **Sonder-Paket** (Größe Klein oder Normal).
- `Leere Regale` (Malus) leert weiter einen Paket-Platz.
- Preisschild über `_pack_price`-Weg: `run.shop_price` + Schnäppchenjäger; Kleingedrucktes erstattet den Paketpreis.
- Rechtsklick/Hover-Auskunft eines Pakets: Sorte, Größe, Kartenzahl, Kartengrößen-Garantie — nie den Inhalt.

## Kauf und Öffnen

- `GameRun.purchase_card_pack(card_pack, price) -> Array[Pack]`: zieht den Preis ab, würfelt den Inhalt, gewährt jede Karte über `grant_pack` (Buchung VOR dem Licht), liefert die Karten.
- Zeremonie (scene_root besitzt Körper, ui/ meldet nur Anker): das Paket hebt sich aus seinem Platz, bricht auf, die Karten fächern kurz über dem Platz auf (lesbar: Sorte + Netz), dann fliegt jede als Komet ins Magazin — derselbe Lieferweg wie heute `pack_purchased` → `_on_pack_purchased` je uid. Ein Abbruch (Laden zu, Laufwechsel) setzt alles hart (Endzustand zuerst, EIN Aufräum-Pfad).

## Körper

- Neue Hülle `CardPackView` (scripts/table/), code-gebaut wie `DataCellView`: EINE Größe für alle Pakete (Regel *EINE Größe je Ding*), etwas größer als eine liegende Karte, damit sie in den Stellplatz der Reihe passt (`slit_size`). Sortenfarbe als Band/Leuchtkante (Farben aus `PackDrawerView`, Misch = mehrfarbig oder neutral, Sonder = Gold wie der Sonderbestand), Größe als Strich-Marken (1–4) oder Zahl auf dem Deckel. Undurchsichtig.
- Steht wie heute die Karten in der Vitrine/auf der Hebebühne ihres Platzes; nutzt die vorhandenen Vitrinen-Fahrten (Band, Absorption) statt neuer Grammatik.

## Nebenwetten

- `SideBet.WARES` bekommt `Payout.CARD_PACK`: Gewicht 8, ab Wert = billigstes passendes Paket; gewählt wird das größte Paket einer gewürfelten Sorte, dessen Preis ≤ Gewinnwert (ein Paket, keine Mehrzahl). Einzelkarten-Arten bleiben.
- Auszahlung = derselbe Weg wie ein Ladenkauf ohne Preis (Inhalt beim Gewinn würfeln, Karten ins Magazin, in der Auszahlungs-Phase wie die Karten bis zum Kassieren zurückgehalten). Tresen-Körper: die Paket-Hülle.

## Tests und Doku

- Unit: Inhalt je Sorte/Größe (Kartenzahl, Garantien, keine Reparatur/Rohling, keine Dubletten), Preise, Kauf bucht alle Karten, Rabatt-Charms, Nebenwetten-Paket.
- Integration: Laden zeigt nur Pakete, Kauf liefert die Karten ins Magazin, Sonder-Paket ab Stufe 8.
- Alte Tests, die Einzelkarten im Laden erwarten, anpassen.
- Doku: CLAUDE.md (UI-Wort-Tabelle; die Invariante zur Kartengröße nennt den Laden — prüfen), `scripts/data|core|ui|table/CLAUDE.md`, kurz und deutsch.
