# Plan: Routen-Deals (per-round choice system)

Implementation plan for the route/deal progression system. Read `CLAUDE.md` first — the layer rules, comment style (short German one-liners), GUT quirks and the scene_root smoke-check rule all apply. Design was settled with the user; do not re-litigate the decisions below, but flag anything that turns out to be technically wrong.

## The design (locked)

Every round, **before play starts**, the player chooses one of **3 routes** ("Deals" with the house) on a hub page. Each deal has a **bonus and a malus, each with its own duration**:

- `INSTANT` — fires once on signing (e.g. +12$).
- `ROUND` — active only for the round it was taken in.
- `BLOCK` — active until the block's **Stresstest** is settled (the name stays **Stresstest**; the settling moment is the **Abrechnung**).

At the Abrechnung (Stresstest round completed, before the shop opens) all block effects reset. Active effects are shown as **tokens on the hub home page** — small tokens for ROUND effects (swept at round end), larger ones for BLOCK effects (swept at the Abrechnung) — with hover tooltips reusing the existing `marker_hint` card.

Temporal archetypes the pool must cover (this is where the strategy lives — the same deal is cheap in round 5 and expensive in round 1):
- **Kredit**: bonus now, malus for the block.
- **Investition**: malus now/this round, bonus for the block.
- **Wette**: both sides this round only.

### Offer composition rules (all mandatory)

1. Three offers per round, slot-structured: slot A = economy deal, slot B = gameplay deal, slot C = wildcard (70% another A/B deal, 30% a rare **all-bonus** deal — these are the former round events).
2. No deal the player already **took** this block is offered again (only taken ones are excluded; if a pool is exhausted, repeats are allowed).
3. While a deal with a benchmark malus is active, **no further benchmark-malus deals are offered** (prevents self-built dead ends).
4. There is **no free option** — every normal deal is priced. Exception: the boss fork (below).
5. On the **Stresstest round**, the three offers come from a separate boss pool instead of the slots.

### The starter pool

All numbers are tunable consts — get the structure right, balance later. Benchmark maluses are **percentages** (the goal curve inflates; flat numbers don't survive it).

Economy (slot A):

| id | Name | Bonus | Malus |
|---|---|---|---|
| `savings_bonus` | Sparprämie | BLOCK: +2$ je übrigem Würfel am Rundenende | BLOCK: Benchmark +25% |
| `advance_payment` | Vorschuss | INSTANT: +12$ | BLOCK: Rundenauszahlung ×0.5 |
| `maintenance_contract` | Wartungsvertrag | BLOCK: je Rundenbeginn 1 zufällige Zahl-Gravur (reuse `roll_stamp_engraving`) | BLOCK: übrige Würfel zahlen nichts |
| `all_on_red` | Alles auf Rot | ROUND: Rundenauszahlung ×3 | ROUND: Benchmark +50% |

Gameplay (slot B):

| id | Name | Bonus | Malus |
|---|---|---|---|
| `high_voltage` | Hochspannung | BLOCK: Überladungs-Deckel +1 (max 5) | BLOCK: Benchmark +15% |
| `overclock_discount` | Übertaktungsrabatt | BLOCK: Übertaktungen −25% | BLOCK: Überladung gedeckelt bei ×2 |
| `odds_package` | Quotenpaket | BLOCK: Nebenwetten zahlen ×2 | BLOCK: Wett-Einsätze ×2 |
| `anchor_clause` | Anker-Klausel | BLOCK: erster Neuwurf jeder Hand kann nicht farkeln | BLOCK: Rundenauszahlung ×0.75 |

Wildcard treats (slot C, 30%, all-bonus — these replace the RoundEvent system):

| id | Name | Bonus |
|---|---|---|
| `happy_hour` | Happy Hour | ROUND: Rundenauszahlung ×2 |
| `tournament_night` | Turniernacht | ROUND: Nebenwetten zahlen ×2 |
| `power_spike` | Spannungsspitze | ROUND: zufällige Kombination im Rampenlicht (nie die gedrosselte) |

Boss pool (Stresstest round only):

| id | Name | Effect |
|---|---|---|
| `double_load` | Doppelbelastung | ROUND: der zweitheißeste Chip ist EBENFALLS gedrosselt; Rundenauszahlung ×2 |
| `goodwill` | Kulanz der Hausleitung | ROUND: keine Drossel; Rundenauszahlung ×0.5 |
| `standard_protocol` | Standardprotokoll | neutral — der Stresstest wie er ist |

Overcharge-cap conflicts (`high_voltage` + `overclock_discount` can coexist): apply the ceiling first, then the bonus — `min(base, 2) + 1`. Document this as a one-liner where it happens.

## What exists today and what happens to it

- **`scripts/data/round_event.gd` is superseded.** Delete it (and its `.uid`); its three events become the wildcard deals above. Remove from `GameRun`: `block_events`, `roll_block_events()`, `round_event()`, `EVENTS_PER_BLOCK_*`, and the event branches of `round_payout_factor` / `side_bet_payout_factor` (these queries survive but become deal-driven).
- **Stresstest machinery stays untouched in shape**: `is_stress_round`, `hottest_combo`, `STRESS_NAME`/`STRESS_HINT`, `DiceScoring.CTX_THROTTLED`, `ComboChipView.set_throttled` (red band + "AUS"), the red roadmap station and its `marker_hint` tooltip. One extension: **throttling becomes plural** for `double_load` — see below.
- **Roadmap markers simplify**: `goal_roadmap_markers` returns only `STRESS_MARKER` or `""` (events are no longer pre-placed on stations). Hub station coloring/hover code stays, event-id branches die.
- **`scene_root._round_note`** drops its event branch (Stresstest only). The taken deal's effects live in the tokens, not the header.

## Implementation

### 1. `scripts/data/route_deal.gd` (new, `class_name RouteDeal extends Resource`)

House pattern like `Charm`/`RoundEvent`: `const` id strings (single source of truth), `_make` + one factory per deal, `all()`, `find(id)`. Fields:

```
id, display_name,
bonus_text, malus_text ("" for all-bonus deals),
bonus_scope, malus_scope (enum Scope { INSTANT, ROUND, BLOCK }),
slot (enum Slot { ECONOMY, GAMEPLAY, TREAT, BOSS }),
color (token/card accent),
raises_benchmark (bool — drives offer-gating rule 3)
```

Display texts are German player-facing sentences ("+2$ je übrigem Würfel", "Benchmark +25% bis zur Abrechnung"). Effects are **not** stored here — they resolve as `GameRun` queries dispatched on the id (never a silent branch in `scene_root`).

After creating the file run the class-cache import (`--import`, see CLAUDE.md) or nothing resolves.

### 2. `GameRun` — state, queries, lifecycle

State:

```gdscript
## Aktive Deals: {id, round} - round = Runde der Unterschrift (ROUND-Scope
## gilt nur in ihr, BLOCK bis zur Abrechnung, INSTANT feuert beim Signieren).
var active_deals: Array[Dictionary] = []
## Angebote der aktuellen Runde (3 RouteDeal-ids); leer = schon gewählt.
var route_offers: Array[String] = []
signal deals_changed
```

Lifecycle methods:

- `roll_route_offers()` — fills `route_offers` per the composition rules (boss pool on stress rounds). Called by scene_root before each round's choice.
- `take_route(id)` — moves the offer into `active_deals`, fires INSTANT effects (Vorschuss books money here), clears `route_offers`, emits `deals_changed`.
- `settle_block_deals()` — the Abrechnung: clears everything. Called by scene_root after the Stresstest round completes.
- ROUND-scope expiry needs no removal pass: a side is active iff `scope == BLOCK or entry.round == round_number` — write one private helper `_deal_active(id, side)` and route every query through it.

Effect queries (each a small method; existing callers keep their names where possible):

- `effective_goal()` → `round_goal` × product of active benchmark maluses (`savings_bonus` +25%, `high_voltage` +15%, `all_on_red` +50%). **`stage_size()` and `cumulative_threshold()` must switch from `round_goal` to `effective_goal()`** — that automatically carries the malus into goal bar, overcharge stages and win check. `effective_goal_for_round(n)` for the roadmap: BLOCK maluses apply to all remaining rounds of the current block, ROUND maluses only to the current round.
- `round_payout_factor() -> float` — product: `all_on_red` ×3, `happy_hour` ×2, `advance_payment` ×0.5, `anchor_clause` ×0.75, `goodwill` ×0.5, `double_load` ×2. (Was int; the two call-site multiplications in `_on_round_complete` need `roundi()`.)
- `deal_unused_die_bonus() -> int` (+2 for `savings_bonus`), `unused_dice_pay() -> bool` (false under `maintenance_contract`).
- `side_bet_payout_factor()` (×2 under `odds_package` or `tournament_night`), `side_bet_stake_factor()` (×2 under `odds_package`) — stake factor applies in `can_place_side_bet`/`place_side_bet` AND in `SideBetPanel`'s stake display (`stake_label` callers), or the button lies about the price.
- `max_overcharge_stages()` — wrap existing result: `min(base, 2)` under `overclock_discount`, then `+1` (capped 5) under `high_voltage`.
- `overclock_price()` — ×0.75 (rounded, min 1) under `overclock_discount`.
- `deal_anchor_active() -> bool` — OR-ed into the `CharmEffects.anchor_saves(...)` call site in scene_root (`scene_root.gd` ~line 3124).
- `apply_round_start_charms()` — grants the Wartungsvertrag engraving (visible via `engravings_changed`), and the throttle block becomes plural:

**Throttling goes plural.** Rename `throttled_combo: String` → `throttled_combos: Array[String]`. Normal stress round: `[hottest_combo()]`; under `double_load` additionally the second-hottest (factor `hottest_combo` into a ranked list helper); under `goodwill`: empty. `DiceScoring.CTX_THROTTLED` now carries the array — `score_category`/`best_hand` check membership instead of equality (`str()` cast dies). `scene_root._set_throttled_combo(key)` → `_set_throttled_combos(keys)`; ctx entry passes the array. Spotlight keeps avoiding all throttled combos. Update the existing throttle tests for the new shape — they pin behavior worth keeping, don't delete them.

Ordering trap: `double_load`/`goodwill` are **taken before the round starts**, and `apply_round_start_charms` runs at round start — so the boss deal must already be in `active_deals` when the throttle is computed. The flow in §3 guarantees that; add a test pinning it.

### 3. `scene_root` — the choice gate

New flow: a round may not start until a route is signed.

- `_on_shop_closed()`: `run.advance_round()` → `run.roll_route_offers()` → open the choice page (§4) → **stop**. The existing `_start_new_round()` call moves into the choice callback: `run.take_route(id)` → close page → `_start_new_round()`.
- Boot / "Neues Spiel" / post-game-over restart: same gate before round 1 — find every `_start_new_round()` call site and route it through the choice. The title-screen boot (game starts a round underneath the title) is the tricky one: roll offers and **auto-pick nothing** — the choice page must be what the player sees after "Neues Spiel"'s `reveal_table()`, before dice fly.
- Abrechnung: in `_on_round_complete`, in the cleared branch, when `GameRun.is_stress_round(run.round_number)`: after the payout/ceremonies and before the shop opens, `run.settle_block_deals()` + token sweep animation (§4).
- `_on_round_complete` payout wiring: `base_blind`/`per_die` use the new queries (`roundi(MONEY_PER_ROUND_CLEAR * run.round_payout_factor())`, per-die zero under `maintenance_contract`, `+ run.deal_unused_die_bonus()`).

`scene_root.gd` changed ⇒ **boot the game via a probe script and screenshot** (memory rule: tests never parse scene_root). Probe must cover: fresh boot → choice page appears → pick a deal → round starts; force round 6 → boss offers appear; complete stress round → tokens swept.

### 4. UI — choice page and tokens

**Choice page** (`scripts/ui/route_choice_view.gd`): a hub page attached like the shop (`HubView.attach_panel` — copy `ShopController`'s attach/open pattern). Three cards side by side: deal name, bonus line (green, `CasinoStyle`), malus line (red), duration tag per side ("diese Runde" / "bis zur Abrechnung" / "sofort"), accent border in `deal.color`. One click = signed (`route_chosen(id)` signal; scene_root wires it). No cancel, no close button — the round only exists past this page. Page title: **"Routenwahl"**; on stress rounds: **"Stresstest-Konditionen"**.

**Tokens** (`HubView`): a token row on the hub home page (rim stage bottom edge is free real estate between the two bonus chips — verify against the current layout before placing). One token per active deal side that is still live: circular chip, accent color, small glyph or 1–2-char label; BLOCK tokens larger than ROUND tokens. Hover → generalize `_show_marker_hint(station, marker)` into `_show_hint(anchor: Control, title, body, accent)` and re-express the station tooltip through it. Rebuild tokens from `run.active_deals` on `deals_changed` and each `_refresh_hub_info` — never mutate incrementally.

**Sweeps**: round end — expired ROUND tokens fade/slide out; Abrechnung — all tokens sweep off together (a simple staggered slide toward the felt edge is fine for v1; a full LED-route ceremony is explicitly deferred). Hide the hint when tokens rebuild (same ghost-tooltip trap as `_rebuild_roadmap`).

**Roadmap**: stations show `effective_goal_for_round(n)` for the current block's remaining stations, so signing a benchmark malus visibly inflates the numbers the moment the token appears.

### 5. Tests

Rewrite the event tests in `test/unit/test_game_run.gd` (they reference deleted API) as deal tests; keep all stress/throttle tests, updated for `throttled_combos`. New coverage, all headless:

- scope logic: ROUND side dead after `advance_round`, BLOCK side alive until `settle_block_deals`, INSTANT fires exactly once (Vorschuss money on `take_route`, never again).
- `effective_goal`: stacking, ROUND-vs-BLOCK inflation, roadmap projection, and that `stage_size`/`stages_cleared` follow it.
- offer composition: slots respected, taken deals excluded within a block, benchmark-malus gating (rule 3), boss pool on stress rounds, exhausted-pool fallback.
- each effect query under its deal id (payout factors compose multiplicatively; overcharge cap `min(base,2)+1` ordering; overclock discount floor of 1).
- `double_load` throttles exactly the two hottest (tie rules unchanged), `goodwill` throttles none, spotlight avoids both.
- integration (`test/integration/`): choice page shows 3 cards and emits `route_chosen`; tokens appear on take, ROUND token gone next round, all gone after settle; hub tooltip on token hover.

GUT quirks that will bite here (from CLAUDE.md, all hit us before): typed-array returns need `PackedStringArray` or `.assign()` — an untyped literal returned as `Array[String]` fails **at runtime only**; `assert_signal_emitted_with_parameters` crashes on bool params; layout asserts need `await wait_frames(2)`.

### 6. Order of work (three commits, suite green at each)

1. **Core**: `RouteDeal`, `GameRun` state/queries/lifecycle, plural throttle in `DiceScoring`, RoundEvent removal, unit tests. (`--import` after adding the class.)
2. **Flow**: scene_root choice gate + payout/anchor/throttle wiring, boot probe verified with screenshots.
3. **UI**: choice page, tokens, sweeps, roadmap projection, hint generalization, integration tests, CLAUDE.md update (rewrite the "Benchmark, Stresstest & round events" section for deals; keep the naming rule: round goal = Benchmark, boss = Stresstest, settlement = Abrechnung).

Commit messages in German per repo style, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` — and document *why* in the body (the diff shows the what).

### Deferred (do not build now)

- "Übertakteter Vertrag" (temporary combo level for a block) — needs an `effective_combo_levels()` overlay threaded through every `run.combo_levels` call site; separate change.
- Shop price factors on charms/dice/packs (only the overclock discount is in scope).
- LED-route token sweep ceremony; v1 uses simple tweens.
- Balance pass on all numbers — structure first.
