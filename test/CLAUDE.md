# test/ — GUT-Testsuite

Ausgelagert aus der Wurzel-CLAUDE.md (2026-08-24, verlustfreies Umsortieren). Die Wurzel trägt Projekt, Commands, Schichtenregel und die globalen Invarianten; Querverweise („siehe *X*") können in einer Schwesterdatei liegen (scripts/table/, scripts/ui/, scripts/core/, scripts/data/, scripts/dice/, test/).

## Testing notes (GUT quirks)

- **`test/unit/`** — fast pure-logic tests (no scene tree). **`test/integration/`** — tests that build nodes.
- GDScript won't auto-convert untyped array literals to the typed `Array[int]`/`Array[String]` these APIs expect — use the `_d()`/`_ids()` helpers (they `.assign()` into typed arrays). Pulling from an untyped `Dictionary` needs an explicit type (`var k: String = h["key"]`, not `:=`).
- `assert_signal_emitted_with_parameters` chokes on **bool** params (crashes in `signal_watcher.gd`/`diff_tool.gd`) — record emitted values manually via a `connect` lambda and assert the resulting array instead.
- `get_global_rect()` on freshly-built container children returns a zero rect until a frame passes — `await wait_frames(2)` before asserting layout.
- For inspector/engraving tests that apply etchings: `view.run = GameRun.new_run()` then `view.run.grant_engraving(Engraving.chisel())`.
