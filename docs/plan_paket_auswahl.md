# Plan: Paket-Auswahl und Würfel-Pakete (2026-11-10)

Spieler-Entscheid, Spec = Obsidian-Seite `E:/Obsidian Vault/Games/Fumble/45 Paket-Auswahl und Würfel-Pakete.md` (lesen, gilt vollständig). Baut auf der UNCOMMITTETEN Karten-Pakete-Welle auf (`docs/plan_karten_pakete.md`, Branch `karten-pakete`, `CardPack`, `CardPackView`, `GameRun.purchase_card_pack`, `ShopController.card_pack_opened`, `scene_root._on_card_pack_opened`/`_settle_pack_openings`) und ersetzt deren „alle Karten bekommen“ durch eine AUSWAHL.

## Kern

- Ein Paket zeigt N **Optionen** (Klein 3 / Normal 4 / Groß 5 / Riesig 5) und erlaubt K **Wahlen** (Klein 1, 20 % → 2; Normal 1, 30 % → 2; Groß 2, 25 % → 3; Riesig 2, 15 % → 3, 3 % → alle). Glück: +1 Prozentpunkt je `GameRun.luck` auf jede Glückswurf-Chance (Deckel 0,60), Hauptgewinn +0,25 Punkte je Glück (Deckel 0,10). Keine Pech-Garantie.
- Jede Wahl darf verfallen; Ungewähltes ist weg, kein Trostpreis.
- Zwei Paket-Arten: **Karten-Paket** (`CardPack`, Sorten Zahlen/Material/Runen/Misch — das SONDER-Paket fällt weg) und **Würfel-Paket** (neu, Sorten Kraft / Serien / Seelen / Material / Misch, siehe Seite 45). Dieselben vier Größen und dieselbe Wahl-Tabelle. Ob ein gemeinsamer Datentyp mit einem `kind` oder zwei Klassen — Entscheidung des Agenten, Hauptsache die Wahl-Logik gibt es EINMAL.
- Karten-Pakete behalten die Größen-Garantien unter den OPTIONEN (Groß ≥1 Große, Riesig ≥1 Kolossale) und das Dubletten-Verbot.
- Würfel: Seelen-Chance je Würfel 15 % + 3 Punkte je Glück, Deckel 75 % (`DiceOffer`, die `shop_soul_rule`/Seelenmarkt-Klausel wirkt weiter obendrauf); Seelen-Paket: immer Seele, Seltenheit eine Stufe gehoben. Material-Paket: ≥2 Material-Seiten.
- Preise: nach ERWARTETEN Wahlen × durchschnittlicher Ladenwert einer Option der Sorte (Karten: Kartenpreise; Würfel: Vorlagenpreis + erwartete Aufpreise) × 1,15 (Auswahl-Prämie), gerundet. Als feste Tabelle, ein Test prüft die Formel (±2). Schnäppchenjäger wirkt auf ALLE Pakete, Mengenrabatt/Trickdieb-Manschette auf Würfel-Pakete, Kleingedrucktes erstattet jeden Paketpreis.
- Gebucht wird BEIM KAUF: Preis, Optionen und Zahl der Wahlen liegen dann fest (Buchung vor dem Licht) — z. B. als offene Auswahl im `GameRun` (`pending_pack_choice` o. ä.). Jede Wahl wird beim Bestätigen gebucht: Karten über `grant_pack`, Würfel in `pending_dice` (der bestehende ZWANG übernimmt). Neu mischen (1 ⚡, einmal je Paket; Charm *Neu gemischt* macht es einmal je RUNDE gratis) würfelt die Optionen über `GameRun` neu, die Zahl der Wahlen bleibt.

## Laden

- Alle Plätze sind Pakete außer Charms und Modulen: drei Karten-Paket-Plätze (wie jetzt), die zwei Würfel-Plätze werden **Würfel-Paket-Plätze** (Einzelwürfel gibt es im normalen Laden nicht mehr; Paket-Hülle `CardPackView` auch dort, Würfel-Pakete mit eigener Kennung — z. B. Würfel-Glyphe/Augen-Punkte statt Streifen — aber DERSELBEN Hülle, Regel *EINE Größe je Ding*).
- Der **Sonderposten-Platz** verkauft wieder eine **einzelne Sonder-Karte** (wie vor den Paketen: `Pack.roll_special_pack`, ab Stufe 8 bzw. Sonderlieferung), gekauft und geliefert wie früher eine Einzelkarte. `CardPack.SORT_SPECIAL` samt `roll_special_offer` entfällt; Misch-Pakete dürfen weiter mit 15 % eine Sonder-Karte enthalten.
- Schwarzmarkt unverändert (Einzelware).
- Hover/Rechtsklick eines Pakets: Art, Sorte, Größe, Optionen, Wahlen („3 von 5 — mit Glück mehr“), Garantie; nie den Inhalt.
- Die Würfel-Einzelkauf-Grammatik (Schale/Ausgabefach) bleibt für Nebenwetten-Würfel und den Schwarzmarkt bestehen.

## Die Auswahl in der WURFGRUBE (scene_root besitzt Körper, ui/ meldet nur)

1. Kauf → Kamera fährt an die Grube (Laden-Seite bleibt offen stehen, wie beim Zwang).
2. Das Paket erscheint über der Grube und bricht auf; Würfel fallen PHYSISCH hinein (der Wurf-Weg des normalen Spiels, so viel wiederverwenden wie geht), kommen zur Ruhe und reihen sich auf wie im Spiel (Schwebe-Stationen). Karten fallen/segeln in die Grube und reihen sich in einer Zeile auf (`DataCellView`, liegend, Regel *EINE Größe je Ding*).
3. ERST der Inhalt, DANN die Zahl: ein Zähler klettert 1 … K und bleibt stehen (~1,5 s Gesamtdauer der Enthüllung, ein Klick überspringt bis zur Wahl); Hauptgewinn „ALLE“ blitzt.
4. Wählen per Klick (Gold-Saum o. ä.), höchstens K; Knöpfe „Nehmen“ (auch mit weniger als K, auch mit 0 = alles verfällt) und „Neu mischen (1 ⚡)“. Die Ansicht ist MODAL wie der Zwang (`_exchange_forced`-Muster): kein Rechtsklick hinaus, keine anderen Fenster, Laden kann nicht schließen. Nur ein Laufwechsel räumt hart ab (Ungewähltes verfällt, schon Gebuchtes bleibt).
5. Bestätigt: gewählte Karten fliegen als Komet ins Magazin, Ungewähltes zerfällt/versinkt. Gewählte Würfel: Kamera an den VORRAT, der bestehende Zwang setzt sie der Reihe nach ein (SERIE), die Kamera bleibt dort, bis alle eingetauscht sind; danach zurück an den Laden.
6. Mehrere Käufe: EIN Paket nach dem anderen (während einer Auswahl ist der Laden ohnehin modal gesperrt).
- Endzustand zuerst, EIN Aufräum-Pfad (`_settle_pack_openings` ausbauen), Generations-Marken. Die bisherige Fächer-Zeremonie über dem Laden-Platz entfällt.
- Die Wurfgrube ist in der Ladenphase leer (Würfel sind geschluckt) — prüfen, dass Grubenwellen/Wurf-Zustand nichts stören und die Runde danach normal startet.

## Nebenwetten

- `SideBet.WARES`: Einzelwürfel und Einzelkarten bleiben; `CARD_PACK` bleibt, dazu `DICE_PACK` (Gewicht ~8, ab billigstem Würfel-Paket, größtes Paket ≤ Gewinnwert).
- Gewonnene Pakete öffnen NACH dem Kassieren in der Grube mit derselben Auswahl (vor der Ladenseite oder als erstes in ihr — Agent entscheidet, eines nach dem anderen).

## Neue Charms (`Charm`, Seltenheit vom Agenten sinnvoll gewählt, Lexikon-Wörter beachten)

- **Sammelalbum**: jedes geöffnete Paket +$1.
- **Neu gemischt**: einmal je Runde Neu mischen gratis.
- **Glückspilz**: Glück +5 (dauerhaft solange gehalten; über denselben Weg wie die Glücks-Klauseln — prüfen, wie `luck` gelesen wird).
- **Beigabe**: jedes Paket zeigt eine Option mehr (Wahlen unverändert).

## Neue Klauseln (`DealClause`, Scope ROUND, Texte im Stil von Seite 39)

- **Glücksgriff** (Bonus T1): Glückswurf-Chancen dieser Runde verdoppelt.
- **Beipack** (Bonus T1): jedes Paket zeigt eine Option mehr.
- **Verplombt** (Malus T1): jedes Paket zeigt eine Option weniger (nie unter K, mindestens 2).
- **Zugabe** (Bonus T2): jedes Paket dieser Runde eine Wahl mehr.
- **Freie Hand** (Bonus T3): das erste Paket dieser Runde — alle Optionen nehmen.
- Großauftrag wirkt weiter auf Kartengrößen in Paketen, Leere Regale leert weiter einen Paket-Platz, Seelenmarkt/Seelenlos auf Würfel-Pakete.

## Tests und Doku

- Unit: Wahl-Tabelle samt Glück (Deckel, Hauptgewinn), Optionen je Größe inkl. Beigabe/Beipack/Verplombt, Würfel-Paket-Inhalt je Sorte, Seelen-Chance aus Glück, Preise vs. Formel, Buchung beim Kauf und beim Bestätigen, Verzichten, Neu mischen (⚡, einmal je Paket, Charm einmal je Runde), Freie Hand nur fürs erste Paket, Sammelalbum, Glückspilz, Nebenwetten-Würfel-Paket.
- Integration: Laden zeigt Würfel-Pakete statt Würfel und eine einzelne Sonder-Karte, Kauf öffnet eine Auswahl, Bestätigen liefert ins Magazin bzw. `pending_dice`.
- Alte Tests auf Einzelwürfel im Laden / Sonder-Paket anpassen.
- Doku kurz und deutsch: root `CLAUDE.md` (UI-Wort-Tabelle: Option/Wahl; Invarianten-Stellen, die den Laden-Würfel oder die Paket-Öffnung nennen; der ZWANG-Abschnitt nennt den Kauf als Quelle), `scripts/data|core|ui|table/CLAUDE.md`, Obsidian-Seite 37 (Charms) und 43 (Verträge/Wetten) um die neuen Einträge ergänzen.
