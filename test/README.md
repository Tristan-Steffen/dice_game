# Tests

Unit tests run with [GUT](https://github.com/bitwes/Gut) (Godot Unit Test),
vendored under `addons/gut/` (v9.7.0, MIT).

## Layout

- `test/unit/` — Tier-1 pure-logic tests (no scene tree, fast, deterministic):
  scoring (`DiceScoring`), charm effects (`CharmEffects`), charm registry
  (`Charm`).

Configuration lives in `.gutconfig.json` at the project root.

## Running headless

From the project root:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```

Exit code is non-zero if any test fails, so this drops straight into CI.

## Running in the editor

The GUT plugin is enabled (`Project > Tools > GUT` panel), or open
`res://addons/gut/GutScene.tscn` and run it.

## Writing a test

Create `test/unit/test_<thing>.gd`:

```gdscript
extends GutTest

func test_something():
    assert_eq(DiceScoring.mult_for("six_kind"), 15)
```

Test files must be prefixed `test_` and functions `test_`.

Note: GDScript does not auto-convert untyped array literals (`[6,6,6]`) to the
typed `Array[int]` / `Array[String]` these APIs expect — use the `_d()` / `_ids()`
helpers in the existing files (they `.assign()` into a typed array). Likewise,
pulling a value out of an untyped `Dictionary` needs an explicit type
(`var key: String = hand["key"]`, not `:=`).
