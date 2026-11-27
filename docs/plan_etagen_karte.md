# Plan: Die ETAGEN-KARTE — Verträge als Weg durch das Casino „Fumble“ (2026-11-27)

Spieler-Entscheide 2026-11-27 (Gespräch, Entwurfs-Skizzen im Chat): die sechs festen Runden
eines Blocks und die drei Zufalls-Karten je Runde werden EIN System. Jeder Block ist eine
ETAGE des Casinos „Fumble“, der Spieler zieht mit einem Puck von Raum zu Raum bis ins Büro
des Pit Boss. RÄUME tragen den Bonus, TÜREN den Malus. Jeder Zug ist eine Runde.

Dieser Plan ersetzt: die Vertrags-Auslage (`route_offers`, `roll_route_offers`, `take_route`,
`RouteChoiceView`), den festen Sechser-Block (`GOAL_BLOCK`, `is_stress_round(n)`,
`block_of_round(n)`) und den Fahrplan am Hub (`goal_roadmap*`, `HubView.set_goal_roadmap`).
Er behält: den ganzen Klausel-Bestand (`DealClause`), `sign_clauses` als EINZIGEN Weg in
`active_deals`, jede Wirkungs-Abfrage über `_clause_active`, die Boss-Konditionen, die
Boss-Prämie (`grant_stress_reward`).

## Regel

### Die Etage

- Eine Etage hat einen EINGANG, acht RÄUME und das BÜRO (Boss). Räume sind durch TÜREN
  verbunden. Der Grundriß kommt aus einer kleinen Zahl fester Vorlagen (siehe *Erzeugung*).
- Jeder Raum trägt genau EINE Bonus-Klausel, sichtbar ab Etagen-Beginn.
- Jede Tür trägt genau EINE Malus-Klausel oder ist FREI (das frühere Werbegeschenk).
  Die drei Türen ins Büro tragen statt dessen je eine BOSS-Kondition, sichtbar ab Beginn.
- Der Inhalt einer Tür ist erst bekannt, wenn der Puck in einem ihrer beiden Räume steht
  (ERKUNDET). Erkundet bleibt erkundet. Ihre STUFE (Farbe) steht ab Beginn fest und ist
  ebenfalls erst erkundet sichtbar.

### Der Zug

- JEDE Runde beginnt mit einem Zug durch eine Tür in einen Nachbarraum. Einzige Ausnahme:
  die allererste Runde eines Laufs wird am Eingang gespielt, ohne Klausel (wie heute Runde 1).
  Auf jeder späteren Etage ist der Eingang nur Standplatz, der erste Zug folgt sofort.
- Der Zug unterschreibt: Malus der Tür (falls vorhanden und noch nicht durchschritten) und
  Bonus des Raums (falls noch nicht besucht). Beides über `sign_clauses`.
- Eine durchschrittene Tür ist AUSGEBRANNT (kein Malus mehr), ein besuchter Raum ist LEER
  (kein Bonus mehr). Zurückgehen ist erlaubt und kostet darum nur die Runde und den Blind-Schritt.
- Der Zug ins Büro macht die Runde zur BOSS-RUNDE mit der Kondition der gewählten Tür.
  Danach Abrechnung, Prämie, Aufzug: die nächste Etage wird gewürfelt.

### Der Blind

- Jeder Zug hebt `blind_value`, gleich wohin: Schritt = `BLIND_GROWTH_BASE` (0,10)
  + `BLIND_GROWTH_STEP` (0,05) × Etage (0-basiert) + `BLIND_MOVE_STEP` (0,02) × (Zug − 1),
  Zug = der wievielte Zug auf DIESER Etage. Der Zug-Zähler fällt mit dem Aufzug auf 0.
- Gerechnet für Etage 1 ab 150: 165 → 184,8 → 210,7 → 244,4 → 288,4 → 346,0. Der kürzeste Weg
  (drei Räume + Büro = vier Züge) trifft den Boss bei 244 — heute steht er nach fünf
  Schritten bei 241,6. Wer alle acht Räume holt, steht deutlich höher.
- Klausel-Wirkungen auf den Blind (Aufschläge, Eichung, Pechsträhne, Hohe Erwartungen)
  bleiben unverändert.

### Fumbles sperren Türen

- Jeder ECHTE Fumble (verziehene zählen nicht) SPERRT eine zufällige Tür der Etage für den
  Rest der Etage. Kandidaten: nicht durchschritten, nicht schon gesperrt, und ihr Wegfall
  trennt den Standraum des Pucks NICHT vom Büro (gangbar = offen oder ausgebrannt).
- Gibt es keinen Kandidaten, passiert nichts. Büro-Türen dürfen gesperrt werden, solange
  ein Weg bleibt — ein fahriger Spieler verliert so auch die Wahl seiner Boss-Kondition.
- Gesperrte Türen zeigen ihren Inhalt nicht mehr.

## Erzeugung (`FloorMap.roll`)

- GRUNDRISSE: fünf bis sechs handgebaute Vorlagen (Räume mit Rasterplatz, Türen als Paare),
  jede mit mindestens einer Sackgasse und drei Büro-Türen, kürzester Weg Eingang → Büro
  immer vier Züge. Fest statt prozedural, weil die Karte später auf einem festen
  Grundriß des Tisches stehen muß (Welle 3).
- RÄUME: 3 × Stufe 1, 3 × Stufe 2, 2 × Stufe 3; Sackgassen bekommen zuerst Stufe 3.
  Bonus aus `DealClause.ids_for(tier, BONUS)`, jede Klausel höchstens einmal je Etage,
  `_clause_offerable` wird beim Würfeln gefragt.
- TÜREN: bei der Erzeugung nur die STUFE — mit 60 % die höhere Stufe ihrer beiden Räume,
  sonst eine darunter (mindestens 1). FREIE Türen: drei Würfe mit `treat_chance()`
  (Werbetrommel wirkt weiter), je Erfolg wird eine zufällige Nicht-Büro-Tür frei.
- Der MALUS einer Tür fällt erst beim ERKUNDEN (der Spieler sieht ihn ohnehin nicht früher):
  aus dem Topf ihrer Stufe, kein Tag gemeinsam mit dem Bonus eines ihrer beiden Räume,
  nicht schon auf der Etage vergeben, `_clause_offerable` mit dem Zustand von JETZT.
  Damit bleibt die heutige Auslage-Sperre für Klauseln ohne Ziel (Pfändung, Schrottpresse,
  Zwangsversteigerung, Projektor-Ausfall) ohne Sonderregel gültig.
- BÜRO-TÜREN: drei verschiedene Boss-Konditionen wie `_roll_boss_offers`.
- RAUM-NAMEN sind Kosmetik aus dem ersten Tag des Bonus: Geld/Auszahlung → Bar bzw. Kasse,
  Werkstatt → Werkstatt, Shop → Lager bzw. Hinterzimmer, Glück → Lounge, Charm → Empore,
  Modul → Labor-Flur, Energie → Generator, Stufe 3 in der Sackgasse → Tresor. Jeder Name
  einmal je Etage, Rest aus einer Ersatzliste.

## Welle 1 — core/ und data/ (spielbar nur in Tests)

- `scripts/data/floor_map.gd` (`FloorMap`, Resource): Räume `{id, name, bonus, tier, cell,
  visited}`, Türen `{a, b, tier, malus, boss, state, scouted}` mit `state` OPEN / PASSED /
  LOCKED, `entrance`, `office`, `position`. Reine Abfragen: `doors_from(room)`,
  `passable(door)`, `reaches_office(from, without_door)`, `lock_candidates()`.
  Vorlagen als `const`-Tabelle, jede Id als `const`-String.
- `GameRun`:
  - Zustand `floor_map`, `floor_index` (0-basiert), `floor_moves`.
  - `move_through(door_id)` ersetzt `take_route`: prüft Nachbarschaft und Zustand, zählt
    `floor_moves`, setzt Tür/Raum, ruft `sign_clauses`, erkundet die Türen des neuen Raums
    (würfelt dort ihren Malus), Signal `floor_changed`.
  - `blind_growth()` wird Instanz-Abfrage aus `floor_index` und `floor_moves`;
    `advance_round` hebt den Blind NICHT mehr selbst — das tut `move_through`, damit
    Vorschau („nächster Blind“ je Tür) und Buchung EINE Rechnung teilen (`next_blind()`).
  - `is_boss_round()` (Puck im Büro) ersetzt `is_stress_round(n)`; `floor_index` ersetzt
    `block_of_round(n)`. Alle Aufrufer umstellen: `_scope_reaches` (Eintrag merkt `floor`),
    `block_fumbles`, `scene_root` (sechs Stellen), `hub_view`.
  - `note_fumble`: nach der bestehenden Buchung `_lock_fumble_door()`; `last_locked_door`
    für die Zeremonie.
  - `settle_block_deals` bleibt die Abrechnung und würfelt danach die nächste Etage
    (`_enter_next_floor`: `floor_index += 1`, `floor_moves = 0`, `FloorMap.roll`).
  - `new_run` würfelt Etage 1; Runde 1 steht am Eingang ohne Klausel.
  - Gestrichen: `route_offers`, `roll_route_offers`, `_roll_treat_slot`, `_draw_card`,
    `_listed_clause_ids`, `_taken_this_block` (die Etage vergibt jede Klausel einmal),
    `goal_roadmap`, `goal_roadmap_index`, `goal_roadmap_markers`, `roadmap_goal`,
    `projected_blind`, `GOAL_BLOCK`, `ROUTE_OFFER_COUNT`, `TREAT_TIER_WEIGHTS`.
- ÜBERGANG bis Welle 2 (das Spiel muß nach Welle 1 booten und spielbar sein): das alte
  Fenster `RouteChoiceView` zeigt die ZÜGE des Standraums als Karten — `move_offers()`
  liefert je gangbarer Tür eine Karte im alten Format (`CARD_TIER`, `CARD_BONUS` = Bonus des
  Zielraums falls unbesucht, `CARD_MALUS` = Malus bzw. Boss-Kondition der Tür falls nicht
  ausgebrannt, dazu Raumname und Tür-Id), `scene_root` ruft statt `take_route(index)`
  `move_through` mit der Tür der Karte. Das Fenster verträgt dafür 1 bis 4 Karten und eine
  Karte ohne beide Seiten („Zurück“). Der Hub-Fahrplan bekommt bis Welle 2 die gespielten
  Blinds der Etage, den laufenden und den nächsten.
- Tests (unit): jede Vorlage zusammenhängend und Büro in vier Zügen erreichbar; Klauseln
  je Etage eindeutig; Tag-Regel Tür gegen beide Räume; Sperre trennt nie vom Büro;
  Rückweg unterschreibt nichts; Blind-Schritte 10/12/14 % und Rücksetzen nach dem Boss;
  Runde 1 ohne Klausel; Stammkunde lebt bis zur Abrechnung der Etage.
  Die bestehenden Tests zu Auslage und Fahrplan werden ersetzt, nicht angepaßt.

## Welle 2 — die Karte als Fenster (spielbar)

- `scripts/ui/floor_map_view.gd` ersetzt `RouteChoiceView` am selben Ort und zum selben
  Zeitpunkt (vor dem ersten Wurf der Runde, modal wie heute): Räume als Kacheln mit Name
  und Bonus-Tag-Farbe, Türen als Stege, erkundete mit Malus-Marke in Stufenfarbe, unerkundete
  mit „?“, gesperrte durchgestrichen, der Puck auf dem Standraum, der gegangene Weg hell.
- Klick auf einen Nachbarraum = Zug. Der Zeiger über Raum oder Tür zeigt den vollen
  Klausel-Text (`DealClause.text_for` mit `deal_bonus_factor()`), über einer gangbaren Tür
  dazu den Blind nach diesem Zug.
- Hub: statt des Fahrplans „Etage n · Zug m“, der laufende Blind und der Schritt des
  nächsten Zugs in Prozent. `DealTokenRow` zeigt weiter die unterschriebenen Klauseln.
- Fumble: die gesperrte Tür blitzt rot, sobald die Karte das nächste Mal steht; bis dahin
  genügt eine Zeile am Hub („Tür gesperrt: Bar → Tresor“).
- Nach dieser Welle wird GESPIELT, bevor Welle 3 beginnt. Zu prüfen: lohnt der lange Weg
  zu oft oder nie (`BLIND_MOVE_STEP`), sperren Fumbles zu viel, wie oft liegt eine freie Tür.

Welle 2 umgesetzt am 2026-11-27. Abweichungen: Eingang und Büro stehen als hohe Kacheln über alle drei Reihen (so liegen alle ihre Türen waagerecht, kein schräger Steg); die Daten-Abfrage heißt `floor_view_state()`, dazu `walkable_doors()` und `move_clauses(door_id)`; `floor_roadmap`, `STRESS_MARKER`, `STRESS_HINT`, `ROADMAP_SHOWN` und `floor_first_round` sind mit dem Fahrplan gestorben; der Hub nennt vor dem Zug groß den Blind NACH ihm („NÄCHSTER BLIND“) und darunter „Zug m: +p %“; `advance_round` meldet `floor_changed`.

## Welle 3 — die Karte wohnt auf der Startseite des Hubs (Spieler-Entscheid 2026-11-27)

Die Karte als Bauteil des Tisches (Pads, Lichtspuren, Messing-Puck) ist verworfen: für einen
Grundriß dieser Größe ist auf dem Deck kein Platz, und der Hub ist ohnehin der Schirm des Hauses.

- `FloorMapView` verläßt den Grubenboden und wird der Hauptteil der HUB-STARTSEITE (dort, wo
  früher der Fahrplan stand). Sie steht dort DAUERND, nicht mehr modal: während der Runde
  zeigt sie den Stand (ein Fumble sperrt seine Tür sichtbar im selben Moment), ist ein Zug
  fällig, sind die gangbaren Nachbarn hervorgehoben und klickbar.
- Der große Blind der Startseite schrumpft in die Kopfzeile der Karte („Etage n · Zug m“
  links, Blind rechts; vor dem Zug „Nächster Blind“ wie bisher). Glück, Fumbles, Vertrags-Marken
  und die Knöpfe der Startseite bleiben.
- Ablauf: „Fertig“ im Laden → die Startseite zeigt die Karte mit fälligem Zug → Klick auf
  einen Raum → der bisherige Ablauf nach dem Zug (Kamera zur Grube, Rundenbeginn). Der
  LOCKRUF der Grube wartet, bis gezogen ist. In Runde 1 ist kein Zug fällig.
- Bedienbar, wo sichtbar: der Klick auf einen gangbaren Raum gilt in jeder Kamera-Lage, in
  der die Startseite zu sehen ist.
- Im LADEN: ein Knopf „Etage“ im Kopf der Ladenseite blättert auf die Karte und zurück
  (nur ansehen, kein Zug, solange der Laden offen ist).
- Der Puck bleibt gemalt.

Welle 3 umgesetzt am 2026-11-27. Abweichungen: die Blind-Zähl-Animation ist entfallen (der Kopf der Karte nennt den Blind ohne Ticken); steht die Kamera nicht am Hub, wenn ein Zug fällig ist (Laden über die Grube verlassen), zeigt die Grube golden „RAUM WÄHLEN / Erst einen Raum wählen (Hub)“ statt WÜRFELN, nach „Fertig“ bleibt die Kamera am Hub; die Laden-Karte ist eine eigene Hub-Seite `FloorMapPage` mit derselben `FloorMapView` (`read_only`); die Karte greift in den Seitenrand des Hubs (`MAP_BLEED_UNITS`).

## Welle 4 — „Bin ich dem Haus noch voraus?“ (Spieler-Entscheid 2026-11-27)

In einem Spiel mit explodierenden Zahlen lesen sich nur Verhältnisse und Raten. Die erste
Gruppe Laufwerte beantwortet die Frage, an der die Zugwahl hängt.

- `GameRun.round_scores`: die erreichten Punkte jeder BEENDETEN Runde, gebucht in
  `advance_round` neben `blind_history` (dieselbe Länge, derselbe Index).
- TYPISCHE Rundenpunkte `typical_score()`: geometrisches Mittel der letzten bis zu
  `SCORE_WINDOW` 3 Runden (geometrisch, weil das Wachstum exponentiell ist); ohne beendete
  Runde gibt es keinen Wert.
- POLSTER `cushion(blind)` = typische Rundenpunkte / Blind, gezeigt als „×3,6“; unter 1 rot.
- TREND: `score_growth()` = geometrisches Mittel der Runde-zu-Runde-Verhältnisse der letzten
  bis zu vier Runden (ab zwei beendeten Runden), `house_growth()` = 1 + Schritt des nächsten
  Zugs. Gezeigt „Du ×1,32 · Haus ×1,14“. Ist das Haus schneller, nennt `rounds_until_caught()`
  die Runden, bis das Polster bei diesem Tempo unter 1 fällt (ln(Polster) / ln(Haus/Du),
  aufgerundet); sonst „voraus“. Der Schritt des Hauses eskaliert je Zug, die Zahl ist darum
  eine Schätzung und heißt auch so („bei diesem Tempo“).
- POLSTER JE TÜR: `blind_after_move(door_id)` = der Blind nach dem Zug SAMT den
  Sofort-Klauseln dieses Zugs (Blind-Aufschläge, Eichung, mit `deal_bonus_factor()`), eine
  reine Vorschau mit derselben Rechnung wie die Buchung. Die Karte zeigt an jedem gangbaren
  Nachbarn bzw. in der Auskunft „Blind 520 · Polster ×2,9“ statt nur „+14 %“.
- ZAHLENFORMAT: EIN Helfer für große Zahlen (bis 99.999 ausgeschrieben mit Tausenderpunkt,
  dann „123 Tsd“, „1,2 Mio“, „3,4 Mrd“, „5,6 Bio“, danach Zehnerpotenz „1,2e15“), deutsches
  Komma. Diese Welle nutzt ihn für die neuen Laufwerte und die Karte; die übrige Anzeige
  bleibt unberührt.
- Anzeige in dieser Welle: Polster und Trend als Lauf-Anzeigen der Hub-Startseite neben
  Glück und Fumbles (mit Hover-Hinweis, der die Rechnung in einem Satz erklärt). Das Diagramm
  (Blind und Rundenpunkte, logarithmisch) kommt mit dem neuen Hub-Layout in Welle 5.
- Wenn ein sauberer Haken da ist, dazu: FUMBLE-QUOTE (echte Fumbles je Wurf) und BESTE HAND.

Welle 4 umgesetzt am 2026-11-27. Abweichungen: die Rundenpunkte lebten nur in `scene_root.hand_total` — sie stehen jetzt in `GameRun.round_points` (`hand_total` ist eine Eigenschaft darauf); `blind_after_move` rechnet auch einen rundenweisen Boss-Aufschlag (Hohe Erwartungen) und die Galgenfrist ein und gleicht darum `effective_goal()` nach dem Zug; das Polster steht nur in der Auskunft, nicht an den Nachbar-Kacheln (zu eng); der Kopf der Karte nennt den Blind ebenfalls über `BigNumber`; BESTE HAND gebaut (`best_hand` über `note_hand_counters`), FUMBLE-QUOTE nicht — kein Wurf läuft durch GameRun.

## Welle 5 — der TURM: die Karte wird senkrecht, schmal und endlos (Spieler-Entscheid 2026-11-27)

- Die Karte läuft von UNTEN nach OBEN, je Reihe bis zu drei Räume. Die Vorlagen werden um
  90° gedreht gelesen (Spalte → Reihe); Regeln und Erzeugung ändern sich nicht.
- Die Etagen STAPELN sich: über dem Büro einer Etage beginnt die nächste. Ihr Eingang wird
  nicht mehr gezeichnet — das Büro darunter ist der Standplatz. Die nächste Etage bleibt
  VERBORGEN bis zum Aufzug (nach der Abrechnung).
- Geschaffte Etagen bleiben als gedimmte Geschichte unter dem Puck stehen
  (`GameRun.floor_history`, nur Anzeige). Der Turm hat keine Obergrenze.
- Auf der Hub-Startseite steht der Turm als schmaler STREIFEN links (rund ein Drittel der
  Breite, volle Höhe): Räume nur als Kachel in Stufenfarbe mit Zustand (besucht, gangbar,
  Standraum mit Puck), Türen als kleine Marken (Stufenfarbe, „?“, frei, rot gesperrt), keine
  Namen. Der Ausschnitt folgt dem Puck; das RAD rollt ihn an der Hub-Station, ein Zug rastet
  auf den Puck zurück.
- Rechts daneben: oben der Blind samt Schritt, darunter die AUSKUNFT (Raum und Tür unter dem
  Zeiger mit vollem Text, Blind und Polster nach dem Zug), darunter die LAUFWERTE (Polster,
  Trend, Fumble-Quote, Glück, Fumbles, Beste Hand — als Raster, das weitere Werte aufnimmt
  und bei Überlauf rollt) und das DIAGRAMM: Blind und Rundenpunkte über die Runden,
  logarithmische Achse, zwei Linien. Unten die Knöpfe wie bisher.
- Die GROSSE Karte bleibt die Hub-Seite `FloorMapPage`, jetzt ebenfalls senkrecht und mit
  Namen und Tür-Marken in lesbarer Größe: ein Klick auf den Streifen (auf keinen gangbaren
  Raum) oder der Knopf „Karte öffnen“ öffnet sie, im Laden der Knopf „Etage“. Gezogen wird
  in beiden Ansichten; im Laden bleibt sie nur zum Ansehen.

Welle 5 umgesetzt am 2026-11-27. Abweichungen: Streifen und große Karte sind EINE Klasse (`FloorMapView`, `compact`), die Geschichte reist als `history` in `floor_view_state()`; die FUMBLE-QUOTE fehlt weiter (kein Wurf läuft durch GameRun), statt ihr steht „Blind-Schritt“ im Raster; die Laufwerte ticken nicht mehr, ein geänderter Wert blitzt nur; die große Karte rollt ohne Fahrt.

## OFFEN (Spieler-Entscheid nötig oder erst im Testspiel zu klären)

- WÖRTER: „Etage“, „Raum“, „Tür“, „Büro“ sind vorläufig. „Boss-Runde“ bleibt (Entscheid
  2026-11-07); „Pit Boss“ wäre nur der Name des Büros.
- EILEN: wer in vier Zügen zum Boss geht, holt Prämien-Würfel und Projektor schneller als
  heute. Gegenmittel, falls nötig: Mindestzahl besuchter Räume oder eine Prämie, die mit
  den besuchten Räumen wächst.
- FREIE TÜREN: drei Würfe zu 30 % sind eine Schätzung gegen die heutigen ~1,5 Werbegeschenke
  je Block.
- LABOR: seine Wartezeit zählt Runden und läuft unverändert, wird aber durch kurze Etagen
  nicht mehr an „sechs Runden je Block“ gemessen.
- SPIELSTAND: es gibt keinen; `FloorMap` bekommt `to_dict`/`from_dict` erst mit ihm.
