# Plan: Die HITZE (Hot Streak) und der Block-Streifen

Spieler-Entscheid 2026-11-28. Löst die ETAGEN-KARTE samt Grundriss ab
(`docs/plan_etagen_karte.md` ist damit Geschichte): der Grundriss war ein zweites
Spiel über dem Würfelspiel. An seine Stelle tritt EIN Pegel und EIN Streifen.

## Regel

- **Block = 6 Runden**, die sechste ist die Boss-Runde (wie vor der Karte:
  `is_stress_round(n)`, n % 6 == 0). Der Blind wächst wieder je RUNDE
  (10 % + 5 % je Block); `BLIND_MOVE_STEP`, Maut und Zug sind gestorben.
- **HITZE** `GameRun.heat`: Stufe 1..5 (`HEAT_MIN`/`HEAT_MAX`), Start 1. Sie
  bleibt über Blöcke erhalten.
- **Jede Runde (außer der Boss-Runde) liegen DREI Deals aus**, einer wird gewählt,
  vor dem ersten Wurf (wie die alte Vertragswahl in der Grube):
  - links der KÜHLERE: Stufe H−1, NUR Bonus, kein Malus. Wahl: Hitze −1.
  - Mitte der GLEICHE: Stufe H. Wahl: Hitze bleibt.
  - rechts der HEISSERE: Stufe H+1. Wahl: Hitze +1.
  - Rand unten (H = 1): links liegt ein zweiter Deal der Stufe 1 (mit Malus,
    Hitze bleibt).
  - Rand oben (H = 5): rechts liegt ein Deal der Stufe 6 (WEISSGLUT). Stufe 6 ist
    kein Hitze-Stand: die Wahl läßt die Hitze auf 5.
- **Was eine Stufe enthält** (eine Tabelle `HEAT_RECIPES` in GameRun, aus den
  bestehenden Klausel-Töpfen `DealClause.Tier`; vorläufig, bis es eigene Klauseln
  für die hohen Stufen gibt):

  | Stufe | Bonus | Malus |
  |---|---|---|
  | 1 | ONE | ONE |
  | 2 | TWO | TWO |
  | 3 | THREE | THREE |
  | 4 | THREE + TWO | THREE + TWO |
  | 5 | THREE + THREE | THREE + THREE |
  | 6 | THREE × 3 | THREE + THREE + eine Boss-Kondition |

  Ziehregeln wie früher (`_draw_clause`): nichts doppelt in der Auslage, nichts,
  was in diesem Block schon unterschrieben ist, kein Tag-Paar Bonus/Malus auf
  derselben Karte, kein zweiter rundenweiser Blind-Aufschlag, `_clause_offerable`.
  Das WERBEGESCHENK (`treat_chance`, Charm Werbetrommel) bleibt: mit dieser Chance
  verliert der MITTLERE Deal seinen Malus.
- **Fumble**: der ERSTE Fumble einer Runde kostet eine Stufe (`HEAT_FUMBLE_LOSS` 1,
  nie unter 1), weitere Fumbles derselben Runde kosten nichts. Gebucht in
  `note_fumble`.
- **Boss-Runde**: es liegen drei Boss-Konditionen aus wie vor der Karte
  (`_roll_boss_offers`), die Wahl ändert die Hitze nicht.
- **Boss-Prämie: nur WÜRFEL, nach der Hitze beim Bestehen** (`grant_stress_reward`):
  Hitze 1–3 ein Würfel, 4–5 zwei; die Güte des Wurfs steigt mit der Hitze
  (Fortschrittsstufe + Hitze − 1 als Stufe für `DiceOffer.roll_reward_die`, sofern
  die Leiter das trägt — sonst der nächstliegende Hebel dort). Der Projektor und
  das Labor bleiben wie sie sind.
- **Nach der Boss-Runde halbiert die Hitze**, aufgerundet (5→3, 4→2, 3→2, 2→1).
  Die Klauseln des Blocks verfallen wie bisher (`settle_block_deals`).
- Buchung vor dem Licht: `GameRun` bucht Hitze, Klauseln und Prämie; die Ansicht
  zeigt nur.

## GameRun (core/)

- Weg: `floor_plan`, `floor_index`, `floor_moves`, `move_due`, `floor_history`,
  `move_to`/`move_through`/`walkable_moves`/`move_clauses`/`move_step_factors`/
  `blind_after_move`/`toll_percent`/`floor_view_state`, `floor_changed`,
  `BLIND_MOVE_STEP`.
- Zurück (Vorlage: Stand `6466b8b`, `git show 6466b8b:scripts/core/game_run.gd`):
  `route_offers`, `roll_route_offers`, `take_route`, `is_stress_round`, der Blind
  je Runde in `advance_round`, `_taken_this_block`. Der Block-Bezug in
  `_scope_reaches`/`sign_clauses` ("floor") wird der Block der Runde.
- Neu: `heat`, `heat_changed`, `HEAT_RECIPES`, eine Karte der Auslage trägt
  `level`, `heat_delta` (−1/0/+1), `bonus: Array[String]`, `malus: Array[String]`
  (die alten Einzel-Schlüssel `CARD_BONUS`/`CARD_MALUS` werden Listen).
  `take_route(index)` bucht Hitze und unterschreibt über `sign_clauses`.
- `blind_after_offer(index)`: der Blind dieser Runde, wenn diese Karte
  unterschrieben wird — dieselbe Rechnung wie die Buchung (Muster
  `blind_after_move`).
- `block_strip_state()`: reine Werte für den Streifen: je Stop der sechs Runden
  `{round, blind (gespielt/laufend/Projektion), state done|now|ahead, boss,
  heat (Stufe, mit der gespielt wurde), pick cool|keep|hot|""}`, dazu `heat`,
  `heat_max`, `block`. Die Geschichte je Block lebt in einem kleinen Feld
  (`block_log`), das mit dem Blockwechsel leert.
- `route_view_state()`: die drei Karten fertig für die Ansicht: Stufe, Stufenname,
  Hitze-Wirkung, je Klausel Name und voller Text (`DealClause.text_for`, Bonus mit
  `deal_bonus_factor`), `blind_after`, `typical`, `margin` (gut/knapp/rot, wie die
  Laufwerte).
- Die LAUFWERTE bleiben (`round_scores`, `typical_score`, Trend, `run_chart`,
  `best_hand`).

## Ansicht

- **Stufennamen** (ui/, eine Quelle): 1 Kühl, 2 Warm, 3 Heiß, 4 Glühend,
  5 Lodernd, 6 Weißglut. Eine eigene Farbleiter von Graublau über Orange nach Rot,
  Weißglut fast weiß — sie darf keiner Wertungsfarbe gleichen (Basis cyan, Mult
  gold, Krit pink, Geld grün, Energie violett).
- **Hub-Startseite** (`HubView`): der Etagen-Streifen links fällt. Oben quer der
  BLOCK-STREIFEN (`BlockStripView`, ui/): sechs Stops in einer Reihe mit Blind,
  geschaffte in der Farbe ihrer Hitze samt Wort („kühler“, „gleich“, „heißer“),
  der laufende hervorgehoben, kommende gestrichelt, der sechste „Pit Boss“ mit
  „zahlt nach Hitze“. Darüber oder daneben der HITZE-PEGEL: fünf Felder, das
  aktuelle benannt, dahinter gestrichelt Weißglut. Blind-Karte, Auskunft,
  `RunValuesGrid`, `RunChartView` und die Deal-Marken bleiben; die Kachel
  „Schlüsselkarte“ wird „Hitze“.
- **Die Wahl in der Grube**: `RouteChoiceView` kommt zurück (Vorlage `6466b8b`),
  drei Karten quer auf dem Grubenboden. Jede Karte: Kopf mit Stufenname und
  Hitze-Wirkung („Hitze −1 · kein Malus“, „Hitze bleibt“, „Hitze +1“, bei
  Weißglut „Hitze bleibt · Weißglut“), darunter die Bonus-Klauseln grün und die
  Malus-Klauseln rot mit vollem Text, am Fuß „Blind 335 · dein Schnitt 300“ mit
  Ampel. Die Karte muß sechs Klauseln tragen können (Weißglut). Boss-Runde:
  Überschrift „Boss-Konditionen“ wie früher. Die Grube ruft „DEAL WÄHLEN“.
- Weg: `FloorPlan`, `FloorPlanView`, `FloorPlanGeometry`, `FloorMapPage` samt
  Laden-Knopf „Etage“, `scene_root.floor_detail` samt `_sync_floor_detail`,
  `_frame_floor_detail`, Rad-Zoom über der Nahsicht, die Proben
  `tools/godot_floor_plan_*`, ihre Tests.
- Die Zeile `table_screen.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)` in
  `scene_root._setup_table_screen` bleibt.

## Tests

- `test/unit/test_heat.gd`: Auslage je Hitze-Stand (Ränder 1 und 5, Weißglut),
  kühler ohne Malus, Buchung der Hitze je Wahl, Fumble (erster kostet, zweiter
  nicht, nie unter 1), Halbierung nach dem Boss, Prämie nach Hitze, Vorschau gleich
  Buchung, Blind je Runde, Streifen-Zustand, ein kopfloser Lauf über drei Blöcke.
- `test/integration/test_route_choice_view.gd`, `test_block_strip_view.gd`.
- Die Tests der Karte fallen; was vor `4343c42` in `test_game_run.gd`,
  `test_progress_tier.gd` und `test_contract_boosters.gd` zum Block stand, kommt
  sinngemäß zurück.

## Doku

Die Punkte „Die ETAGEN-KARTE ist ein GRUNDRISS“ und „Die ETAGEN-KARTE“ in der
Wurzel-`CLAUDE.md` werden EIN kurzer Punkt „Die HITZE“; der Blind-Punkt und der
Rad-Punkt werden berichtigt; ebenso die Abschnitte in `scripts/core/CLAUDE.md`,
`scripts/ui/CLAUDE.md`, `scripts/data/CLAUDE.md`.

## OFFEN

- Eigene Klauseln für Stufe 4–6 statt gestapelter.
- Balance: Fumble-Verlust, Würfelzahl der Prämie, Rezepte.

## Umgesetzt am 2026-11-28

Abweichungen: Stufennamen und Farbleiter wohnen in `HeatStyle` (ui/); `route_view_state()` liefert darum die Stufe
(`level`, `heat_delta`, `treat`, `boss`) statt des Namens, die Ansicht setzt Name und Hitze-Wirkung daraus zusammen
(core/ darf ui/ nicht kennen). Die Güte des Prämien-Wurfs: `DiceOffer.roll_reward_die` liest seine Stufe nur als
Augenwachstum - die Seele steigt mit der Hitze nicht. `block_strip_state()` trägt zusätzlich `pending`, `round`, `blind`,
`step_percent`, `boss_round`, `reward_dice` für Blind-Karte und Auskunft. Das Werbegeschenk nennt sich auf der Karte
(„· Werbegeschenk“). Wahl-Wort je Runde aus Stufe gegen Hitze (am unteren Rand liest der linke Deal „gleich“).
Mehrere Prämien-Würfel spielen ihre Zeremonie nacheinander. Hub: Streifen oben quer, darunter links Blind-Karte und
Auskunft, rechts Laufwerte und Diagramm.
