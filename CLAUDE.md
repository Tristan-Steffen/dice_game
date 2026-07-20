# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Fumble** — a Balatro-like 3D dice roguelike built in **Godot 4.7** (`gl_compatibility` renderer, Jolt physics). Code comments and in-game text are in **German**; identifiers are a mix. The whole game plays on a single table surface at world **Y = 0**, viewed as a "casino table screen": 2D UI is rendered into a `SubViewport` and displayed on a mesh (see Architecture).

**Comments:** keep them to the necessary minimum — short German one-liners that state a non-obvious rule, constraint, or design decision. Don't restate what the code already says, don't duplicate a `description` string that sits one line below, and don't write essay-length narrative blocks or "siehe X" cross-reference chains. When in doubt, cut it.

## Commands

The Godot binary lives outside the repo at `E:/Godot/Godot_v4.7-stable_win64_console.exe` (use the `_console` build so stdout/stderr are captured).

```bash
# Run the full test suite (headless, GUT). Exit code is non-zero on failure.
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

# Run a single test SCRIPT (-gtest often falls through to the full suite; prefer -gdir on the file's folder + a unit script, or filter by directory):
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

# Register newly added `class_name`s in the class cache (required after adding a new global class before it resolves in tests/probes):
E:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . --import

# Run the game:
E:/Godot/Godot_v4.7-stable_win64_console.exe --path .

# One-off visual/logic probe script (ad-hoc scene):
E:/Godot/Godot_v4.7-stable_win64_console.exe --path . --resolution 1280x720 --script <path-to.gd>
```

CI (`.github/workflows/tests.yml`) runs the same GUT command on Linux after a `--editor --quit` import pass. Test config is `.gutconfig.json` (scans `res://test/`, prefix `test_`, suffix `.gd`).

**Note:** `network-diag*.ps1` at the repo root are pre-existing, unrelated diagnostic scripts — never commit them.

## Architecture

### Layered `scripts/` — the folder IS the dependency rule
`core/` and `data/` must not import from folders below them. New scripts are placed by layer, not by feature:

- **`data/`** — `Resource` records only: `DieDefinition` (per-die faces/materials), `Charm`, `Engraving`, `Pack` (sealed shop goods), `DieMaterial`. Each type's ids are `const` string constants (single source of truth) so a typo is a compile error, not a silent no-op that never matches in a `match`.
- **`core/`** — pure logic, **no Nodes** (all `RefCounted`/static): `DiceScoring` (Balatro-style hand values = base points × multiplier), `CharmEffects`/`EtchingEffects`/`MaterialEffects` (id-dispatched effect resolution), `GameRun` (the persistent run state — money, 30-die pool, charms, engravings, sealed packs, round progress; owns all economy methods and emits signals to the UI), `ScoreBreakdown`, `SlotMachine`, `SideBet`, `DiceOffer` (dice templates + refinement rolls, shared with `Pack`).
- **`dice/`** — the physical die: `DiceController` (physics of the 6 dice slots — throw/hold/rest-detection; which value shows comes from each slot's `DieDefinition`, physics only reports which physical face is up), `DieBuilder` (builds dice entirely in code — no `.tscn`), `DieFaceDisplay`, `RotatableDieView` (isolated-world drag-to-rotate preview with face/edge picking).
- **`table/`** — 3D props, camera, and the on-table screen system (see below).
- **`ui/`** — 2D panels and styling shown inside the table screen (`ShopController`, `WorkshopView` — the Werkstatt stash that opens packs and hosts `DieInspectorView` (the engraving station) via `attach_station` —, `SlotBankView`, `SideBetPanel`, `CharmLibraryView`, `EngravingRenderer`, `CasinoStyle`, plus the shared builders `DiceRowView`/`CharmThumb`).

### `scene_root.gd` — the single coordinator
Top-level `Node3D` (not in a subfolder). Owns exactly one `GameRun`, wires its signals to the UI, drives round flow (throw → score → take/reroll → round-goal → shop), and passes the same `GameRun` instance (typed) to `ShopController` and `DieInspectorView`, which mutate state **only** through `GameRun` methods. It also does mouse-forwarding: `_forward_screen_mouse` projects window clicks onto the table plane and `push_input`s them into the `SubViewport`; `_screen_forwards_pixel` gates which rects forward per camera mode. `_ready` is split into named setup steps (`_setup_dice`/`_setup_table_screen`/`_setup_camera_targets`/`_setup_panels`/`_setup_settings_ui`); camera raycasts go through the shared `_ray_pick(pos, mask)` helper and click zones through `_add_click_zone`.

### The table-as-screen display system (`table/`)
- **`TableScreen`** (`table_screen.gd`) — a `SubViewport` rendering 2D UI to a `ViewportTexture` on the "Screen" mesh. Its windows live inside it: `HubView` (home page + `ShopController` as an attached page), `WorkshopView`, `SlotBankView`, `SideBetPanel`, `TreasureChestView`.
- **Hub vs. Werkstatt** — the split is *buy vs. use*: the hub is the casino side (round/roadmap, money, license upgrades, shop — everything sealed), the Werkstatt is the player's workbench (opening packs, the Vorräte stock, applying engravings). Anything dice-shaped belongs at the workbench corner.
- **"Windows"** — each UI region (HUD/`HubView`, combinations cluster, goal bar, dice pit) is a bordered panel with a shared `window_style()`. Outside the windows is dark-purple casino felt via `assets/shaders/table_felt.gdshader`.
- **Reflections** — no SSR in `gl_compatibility`. `ScreenReflection` (`screen_reflection.gd`) is a `SubViewport` with a mirror camera (main camera mirrored across the plane, negated-X basis) rendering reflection-layer (`1<<10`) instances into a texture. `assets/shaders/screen_glass.gdshader` (`render_mode unshaded`, so scene lights don't paint the glass) blends UI + masked reflection; window rects/radii are pushed into its `window_*` uniforms by `TableScreen._sync_reflection_windows()`. `ScreenReflection.mark_reflective(root)` ORs the layer bit onto `VisualInstance3D`s.
- **`CameraRig`** (`camera_rig.gd`) — overview camera tilts to follow the mouse each frame. `set_tilt_locked(true)` freezes it (used while dragging the projected die); on release it holds for `TILT_RESUME_HOLD` (0.5 s) then `smoothstep`-eases the look-around back over `TILT_RESUME_EASE` (1.0 s) rather than snapping. `release_tilt_immediately()` cuts the resume short.

### Extending content
A new **charm** or **engraving** needs no registration map: add a factory method + `all()` entry in the `data/` class and its effect in the matching `core/` effects class, both wired by the same id constant. **Asset filename = content id** (`assets/models/<charm_id>.glb`, `assets/textures/engravings/<engraving_id>.jpg`); paths are derived by convention. `DieDefinition` is shared by reference — call `instantiate()` before mutating a die you take ownership of, or a later upgrade mutates every die sharing that definition.

## Testing notes (GUT quirks)

- **`test/unit/`** — fast pure-logic tests (no scene tree). **`test/integration/`** — tests that build nodes.
- GDScript won't auto-convert untyped array literals to the typed `Array[int]`/`Array[String]` these APIs expect — use the `_d()`/`_ids()` helpers (they `.assign()` into typed arrays). Pulling from an untyped `Dictionary` needs an explicit type (`var k: String = h["key"]`, not `:=`).
- `assert_signal_emitted_with_parameters` chokes on **bool** params (crashes in `signal_watcher.gd`/`diff_tool.gd`) — record emitted values manually via a `connect` lambda and assert the resulting array instead.
- `get_global_rect()` on freshly-built container children returns a zero rect until a frame passes — `await wait_frames(2)` before asserting layout.
- For inspector/engraving tests that apply etchings: `view.run = GameRun.new_run()` then `view.run.grant_engraving(Engraving.chisel())`.
