# Roadmap

Legend: ✔ done · ◐ in progress · ○ planned · ? idea, not decided

## Phase 1 — Faithful port to Godot ✔
Goal: the original JS game (`reference/`) running in Godot, same behaviour and look, exported to web.
1. ✔ Project skeleton, `AGENTS.md`, docs, tools.
2. ✔ Inventory of the JS code (`docs/port_inventory_*.md`).
3. ✔ Contracts between modules (`docs/port_contracts.md`).
4. ✔ Port: `combat/sim`, `combat/view`, `ui` + `combat/hud`, `core/sound`, AI, data `.tres`, i18n (English base + Catalan).
5. ✔ Integration: the game starts, plays and ends like the original.
6. ✔ Tests, lint, web export, review. Open: testing on real phones, visual deviations (`pending_decisions.md`).

## Phase 2 — Screen structure and story-mode foundations ○
- Screen router and the full screen tree (`docs/screens.md`).
- Save system (progress, stars, upgrades).
- Level data format (`data/levels/*.tres`).

## Phase 3 — Story mode ○
- Campaign map across Catalonia, by season.
- Larval moults L1–L5 as level-ups, upgrade tree in the winter nest ("El Bolsó").
- ~30 levels with rising difficulty; enemies based on real predators.

## Phase 4 — Free mode with factions ○
- Playable factions: ? processionary, great tit, hoopoe, ants, *Calosoma* beetle, bat. Each with a signature weapon.

## Phase 5 — Polish ○
- Bestiary with real natural-history facts, sprites for enemies (Meshy → sprites), Android export.
