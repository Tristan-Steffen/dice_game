# Plan: SCHWARZMARKT Runde 2 — Neuwurf je Fach, massive Fächer, heller (2026-11-26)

Baut auf `docs/plan_schwarzmarkt_schubfaecher.md` und dem Stand im Arbeitsbaum auf
(`SecretShopBody`, `SecretShopView`, `SecretShopInfoView`, `scene_root._sync_secret_body`).
Spieler-Wünsche, wörtlich sinngemäß: jedes Fach würfelt für sich neu, 1 Energie je Fach;
die Fächer sind MASSIV (der Schnitt quer durch jedes Fach stört — daß es eingefahren
physisch nicht ins Gehäuse paßt, wird bewußt hingenommen); der ganze Schwarzmarkt soll
weniger dunkel sein, und dafür drei Entwürfe zur Wahl.

## 1. Neuwurf je Fach (core + ui + table)

- `GameRun.reroll_secret_offer(index) -> bool`: kostet `secret_reroll_cost()` = 1 ⚡
  (`SECRET_REROLL_BASE` 1), würfelt NUR Platz `index` neu, auch einen verkauften (der Platz
  bekommt frische Ware); `secret_rerolls` zählt weiter, `secret_stock_changed` feuert.
  Platz 0 = Charm-Angebot (wie `_secret_charm_offer`, Ausschlüsse unverändert), Platz 1 =
  Sonderbestand (`_secret_special_offer`), Platz 2 = Wildcard (`_secret_wildcard_offer`,
  samt Powerbank-Chance). Ein Platz schließt keine Ware aus, die in einem ANDEREN Platz liegt,
  anders als die heutigen Ausschlüsse es schon tun (bestehende Regeln wiederverwenden).
- Der PROJEKTOR ersetzt nicht mehr beide Ware-Plätze: er ist eine Ware wie jede andere und
  belegt EIN Fach (er paßt in eines). Er kann bei jedem Wurf der Plätze 1 oder 2 erscheinen,
  mit `secret_projector_chance` (nie bei vollen Ports, nie zweimal zugleich). `secret_stock`
  hat damit immer genau drei Einträge; der Sonderfall „zwei Einträge“ samt geschlossenem
  drittem Fach stirbt überall (GameRun, View, Body, scene_root, Tests).
- `reroll_secret_stock` (die ganze Auslage) stirbt; `_roll_secret_stock` bleibt für den
  Laufstart. Tests, die ihn nutzen, umstellen.
- `SecretShopView`: je Fach ein Neuwurf-Knopf (unsichtbarer Knopf wie die übrigen, Rechteck
  gemeldet, z. B. `reroll_rect(i)`), `reroll_state(i)` (Preis, bezahlbar), Kauf-Regel wie heute
  (nur an der eigenen Station, aus der Ferne wird der Klick zum Zoom). Die Taste NEU MISCHEN im
  Fußband stirbt samt Preisfenster; das Fußband trägt nur noch die Kontaktleiste.
- `SecretShopBody`: der Neuwurf-Knopf ist ein Körper an der NASE des Fachs (neben Preis bzw.
  „VERKAUFT“, sichtbar auch bei eingefahrenem Fach — so wird ein verkaufter Platz neu bestückt):
  kleine Taste mit Kreispfeil und „1 ⚡“, gedimmt ohne Energie. Ablauf je Fach wie der heutige
  Gesamt-Neuwurf: mit der alten Ware ein, drinnen tauschen, mit der neuen aus — nur dieses Fach.
  Ton `shop_flip` je Fach-Neuwurf (scene_root erkennt ihn wie heute an `secret_rerolls`).

## 2. Massive Fächer (table)

- Jedes Fach ist EIN Stück: Schale, Boden, Wände und Nase fahren zusammen, kein zweites
  Segment, kein Schnitt (`_outer`/`_inner`-Teleskop stirbt).
- Eingefahren reicht das Fach hinten über das Gehäuse hinaus. Was hinter der Gehäuse-
  Rückwand läge, darf NICHT zu sehen sein: es wird an der Rückwand abgeschnitten (z. B. ein
  Clip im Shader aller Fach- und Ware-Materialien gegen die lokale Rückwand, oder eine andere
  saubere Lösung — keine Teile, die hinter dem Gehäuse auf dem Tisch auftauchen). Auch die
  Ware wird an der Rückwand verdeckt, statt dort stehenzubleiben (`ware_center`-Sonderweg
  prüfen, ob er dann noch gebraucht wird; die Regeln „Würfel zeichnet durch das Dach“ und
  „Hologramm nur ganz offen“ bleiben).
- Test „nichts ragt eingefahren hinten hinaus“ wird zu „nichts ist hinter der Rückwand
  sichtbar“ (prüfbar über die Clip-Grenze bzw. Sichtbarkeit).

## 3. Weniger dunkel — DREI Entwürfe zur Wahl (table)

Heute ist fast alles texturloses Schwarz (Lack, Glas, Nasen, Gehäuse). Ziel: man soll die Form
lesen. Rahmen: sauber-futuristisches Casino, behagliches Neon, edel; KEIN Retro. Am Tisch
beleuchtet nichts — jedes Teil liest mit Eigenlicht (unter der Bloom-Schwelle) bzw. dem
festen Schlüssellicht von `chip_steel`. Alle drei Entwürfe in `SecretShopBody` über EINE
Stil-Tabelle umschaltbar (z. B. `STYLE`/`STYLES`), Maße und Mechanik identisch:

- **A · GRAPHIT**: gebürstetes Graphit/Gunmetal statt Lack (Bürstspur, Fasen mit hellem
  Glanzgrat), Stahlrahmen hell, Lüftungsschlitze und Schrauben an Gehäuse und Nasen,
  Fachböden dunkelviolett mit hellerem Raster.
- **B · NACHTVIOLETT**: tiefer Pflaumen-Lack mit sichtbarem Glanz und hellen violetten
  Fasen, Messing-Zierkanten und Messing-Griffe, Fachböden wie heute, aber heller.
- **C · PERLMUTT**: helles Perlgrau/Weiß als Gehäuse und Nasen (Casino-Labor), violette
  Akzente und Leuchtkanten, dunkle Glasflächen nur noch für Info-Display und Preisfenster.

Jeder Entwurf bekommt Oberflächen-Detail statt glatter Flächen (Paneelfugen, Schrauben,
Lochblech/Lüftung, Kantenglanz). Kontrast prüfen: Namen, Preise und Ware müssen auf jedem
lesbar bleiben (die Ware ist oft violett/neon).

## Proben

`tools/godot_secret_shop_probe.gd` erweitern: je Entwurf Station mit voller Auslage, Nahsicht,
ein Fach mitten im Neuwurf (zeigt den massiven Schub), ein verkauftes Fach, Übersicht.
Bilder nach `E:/Generated Images/Fumble/schwarzmarkt_runde2_2026-11-26/<a|b|c>_*.png` plus
EIN `vergleich.png` (die drei Stationsbilder nebeneinander). Voreinstellung bis zur Wahl: A.

## Doku

Wurzel-`CLAUDE.md` (Schwarzmarkt-Punkt und *Charm-Plätze sind PROJEKTOREN*: der Projektor
ersetzt nicht mehr beide Plätze), `scripts/core/CLAUDE.md` (*Energie & Schwarzmarkt*:
Neuwurf je Platz, 1 ⚡), `scripts/table/CLAUDE.md` (`SecretShopBody`), `scripts/ui/CLAUDE.md`
(`SecretShopView`) — knapp, Überholtes als Geschichte markieren.
