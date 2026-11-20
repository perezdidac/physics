# CUCS — Tactical war of the processionary caterpillar

Turn-based artillery game (in the style of *Worms*) where squads of pine processionary caterpillars fight across Catalan landscapes. Made with **Godot 4.7** and playable in the browser.

> Status: **phase 1, porting** the original JS/canvas game (kept in `reference/`) to Godot. See `docs/status.md`.

## Play the original web version
```bash
python3 -m http.server -d reference 8000
```
Then open http://localhost:8000.

## Open the Godot project
1. Install Godot 4.7 (standard build, not .NET).
2. Open `project.godot` from the Godot project manager, or run `godot --path .`.
3. For the web build, install the export templates (*Editor → Manage Export Templates*) and run `bash tools/export_web.sh`.

## Languages
English and Catalan (`i18n/`).

## For contributors and AI agents
Read `AGENTS.md` first.
