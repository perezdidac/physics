# AGENTS.md — How to work on CUCS

Rules for every agent (Claude Code, Antigravity, Cursor) and every person. Read it all before touching anything. Keep this file under 12,000 characters (Antigravity's limit): put details in `docs/`, not here.

## 1. What the project is
**CUCS** is a turn-based artillery game in the style of *Worms*: squads of pine processionary caterpillars (*Thaumetopoea pityocampa*) fight across Catalan landscapes, with wind, destructible terrain and quirky weapons. It is built in **Godot 4.7, GDScript, GL Compatibility renderer**, and the main target is the **web export** (it must run in a browser with nothing installed), then Android.

The original game was a plain JS/canvas web page. It lives untouched in `reference/` as the specification for the port. **Phase 1 is a faithful 1:1 port**: same behaviour and look, no new features. Later phases add a story mode (a campaign across Catalonia following the caterpillar's life cycle, with RPG upgrades) and a free mode with animal factions. See `docs/roadmap.md`.

| Document | Purpose |
|---|---|
| `docs/bible.md` | **What** the game is: only decisions already taken. |
| `docs/status.md` | **How** it is built and **where** we are. Update it in every commit. |
| `docs/roadmap.md` | **What** we want to do, by phase. |
| `docs/screens.md` | Screen flow. |
| `docs/pending_decisions.md` | Questions waiting for the authors. Add yours here. |
| `docs/port_inventory_sim.md`, `docs/port_inventory_view.md`, `docs/port_contracts.md` | Phase 1 only: what the JS does and how it maps to Godot. |

## 2. Golden rules
1. **Language.** Everything in the repository is in **English**: code, comments, docs, commit messages, PRs. The game's text is in English as the base language and translated to **Catalan** (`i18n/ca.po`). Never hard-code player-facing text: use `tr("KEY")`.
2. **Branches.** `uridev` is our main branch. Every task starts a branch from `uridev` and merges back into `uridev`. **Never merge into or push to `main`** unless the authors explicitly ask.
3. **Commits.** We make few, large commits. **Never commit, merge or push unless a human explicitly asks you to.** Leave your changes in the working tree for review.
4. **Do not invent design.** Story, characters, factions, balance and tone are the authors' decisions. If something is not decided, write it in `docs/pending_decisions.md` and ask.
5. **Phase 1 = faithful port.** If the JS does it, the port does it the same way, even if it looks odd. Improvements go to `docs/pending_decisions.md`.
6. **`reference/` is read-only.**
7. **Every behaviour change has a test** (new or extended) in `tests/`.
8. **Simplify before adding.** Small, readable files; no dead code.

## 3. Run, check and test
Godot 4.7 must be on the PATH as `godot`.

```bash
godot --headless --path . --import        # reimport (REQUIRED after new class_name or new assets)
bash tools/lint.sh                        # all GDScript warnings as errors: must print "LINT: N scripts, 0 failures"
bash tools/run_tests.sh                   # all headless tests: must print "TESTS: N, 0 failures"
bash tools/run_tests.sh Terrain Wind      # only tests whose name contains those words
bash tools/export_web.sh                  # web build in build/web/ (needs the Web export templates)
python3 -m http.server -d build/web 8000  # play it at http://localhost:8000
```

A test is a scene `tests/TestName.tscn` with a script `tests/test_name.gd` that prints `OK ...` / `FAIL ...` lines and ends with `RESULT: ALL GOOD` when nothing failed, then quits.

## 4. Code conventions
- **Typed GDScript** (`var x: float`; `:=` only when the type is obvious). Lint treats as errors: unused variables/parameters, shadowing, integer division without `@warning_ignore("integer_division")`, redundant `await`, unreachable code.
- **Names in English**, `snake_case` files and functions, `PascalCase` classes and scenes. `##` doc comments on classes and public functions.
- **Logic separate from drawing.** `combat/sim/` is pure logic (no nodes that draw, no input, no audio): it can run headless in tests. `combat/view/` only draws what the sim says. Communication sim → view through signals or by the view reading sim state.
- **Data in `data/`** as Resources (`.tres`) with a script in `data/types/`: weapons, maps, hats, names, difficulty. No magic tables buried in code.
- **Art paths only through `core/art_catalog.gd`**, colours only through `core/palette.gd`. No loose `res://assets/...` or `Color(...)` in gameplay code.
- **Dependencies point down:** `core/` depends on nothing else; `combat/`, `ui/` use `core/` and `data/`, never the other way round.
- **A module receives what it uses**, not the whole scene.
- **Web first:** no threads, no C#, no desktop-only APIs. Audio starts after the first user tap.

## 5. Architecture in five lines
- `core/` autoloads: `GameState` (current match settings and progress), `Options`, `Sound`, `ScreenRouter` (the only place that changes screens), plus `ArtCatalog` and `Palette`.
- `combat/` the battle: `sim/` (terrain, ballistics, wind, turns, damage, weapons, AI), `view/` (rendering, camera, parallax, caterpillar bodies, effects), `hud/`, and `CombatScreen.tscn` which wires them.
- `ui/` menus and shared widgets, with one `theme.tres`.
- `data/` all content; `assets/` images, audio, fonts; `i18n/` translations.
- `tests/` headless tests; `tools/` scripts (lint, tests, export).

## 6. Working with several agents
A coordinator splits the work; each agent owns **only the folders it was given** and must not edit others. Shared contracts (class names, signals, data shapes) are in `docs/port_contracts.md`: if you need to change one, stop and ask the coordinator. At the end, report: files touched, tests run and their result, and anything left undone.

## 7. Before you finish
1. `godot --headless --path . --import`, `bash tools/lint.sh` and the tests of what you touched pass.
2. `docs/status.md` describes what you changed.
3. Nothing committed unless asked.
