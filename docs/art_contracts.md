# Art contracts

Every visible thing is a `ThingArt`: either a hand-authored SVG sprite or a procedural drawing. Code stays procedural only for
animation and effects (glows, crosses, ropes, particles).

## Architecture (`art/`)

| Class | Role |
|---|---|
| `ArtKit` | Static drawing primitives: `poly` (fill + stroke), ellipse / round-rect / circle fill+stroke, curves, dashes, radial and vertical gradients, `soft_shadow`, `place` / `reset` (draw transform), `hex` (cached colour parse), `night_tint`. `ViewUtil` and `ViewColors.h` are thin wrappers over it; new code calls `ArtKit`. |
| `ArtContext` | What an art may read besides its state: `t` (clock), `wind`, `night`, `combat` (the view's `ViewCtx`, may be null). One instance per view, refreshed per frame (`refresh(vctx)`, `ArtContext.of(vctx)` for static helpers). |
| `ThingArt` | Base class, one drawable kind. `draw(ci, state, ctx)`, `sample_state()` (for the sheet and tests), `vector_fallback()`, `sample_extent()`. An art leaves the draw transform at identity. |
| `SpriteArt` | A `ThingArt` that draws `assets/sprites/<group>/<id>.svg` and draws its `fallback` ThingArt when the file is missing. Template hooks: `_origin`, `_box`, `_rotation`, `_flip`, `_modulate`, `_underlay`, `_overlay`. |
| `CutoutRig` | Mechanism for sprite creatures: named SVG parts `assets/sprites/<group>/<id>/<part>.svg`, each with a pivot and a rest offset; the creature's code sets a pose per part per frame (`set_pose`) and calls `draw`. `is_complete()` is false while a part is missing, so the creature keeps its vector art. No creature uses it yet. |
| `FuncArt` | Adapter that wraps an existing static draw function (creatures, weapons, scene passes) so it is reachable through the registry until replaced. |
| `ArtRegistry` | Kind id -> `ThingArt`. `ArtRegistry.draw(id, ci, state, ctx)`. Exact ids first, then the longest registered prefix (`add_prefix`) for families (`creature:LARVA` covers `LARVA_L1..L5`, `flora:` is the default plant, `boss:` the plain blob). |

Views never name a concrete art: `combat_view.gd`, `caterpillar_art.gd`, `boss_art.gd` and the platform views draw through
`ArtRegistry`. Each lists the ids it draws in `const ART_KINDS`; `tests/test_art_registry.gd` checks they all resolve.

## Registry groups (one file each, so parallel work never collides)

`art/groups/<group>_group.gd` has `static func register(reg: ArtRegistry)`. Add a kind = write its class + one `reg.add(...)` line in
its group file. A new group = a new file + one line in `ArtRegistry.GROUPS`.

| File | Kinds |
|---|---|
| `props_group.gd` | barrel, crate, parachute, mine, caganer, rovello, escudella, tombstone, pine_nut |
| `flora_group.gd` | `flora:<TYPE>` per plant type, `flora:` default |
| `platform_props_group.gd` | `platform:` puddle, needle, tuft, nutrient, checkpoint, goal |
| `weapons_group.gd` | `weapon:held`, `weapon:projectile`, `weapon:plane` (adapters) |
| `creatures_combat_group.gd` | `creature:<KIND>` (ant, boar, calosoma, forestry worker, fly, tits, larva*, egg default) (adapters) |
| `creatures_platform_group.gd` | `platform:` pupa, moth, nightjar, bat, hoopoe (adapters; state `{r, o}` or the options dict) |
| `bosses_group.gd` | `boss:<art key>` (adapters), `boss:` blob |
| `scene_group.gd` | silk nest/web, updraft, larvae swarm, grapple, tethers, contact shadows, tuft(_front), anthill, convoy, nest, spores, boar warning |

Folders: `art/props`, `art/flora`, `art/platform`, `art/scene` hold the kind classes (`barrel_art.gd` = sprite, `barrel_vector_art.gd` = its
vector fallback). Terrain (solids, slopes, sky, water) is not a kind and stays in its views.

## Adding or replacing a sprite

1. Draw `assets/sprites/<group>/<id>.svg` (rules below). Godot imports it; the import file needs `svg/scale=2.0` (copy the one of
   `assets/sprites/props/barrel.svg.import`; a first `godot --headless --path . --import` creates it with scale 1.0, so edit it and import again).
2. Make a small subclass of `SpriteArt` (see `art/props/barrel_art.gd`): call `super(group, id, box, VectorFallbackArt.new())`, set `anchor`,
   override `_origin` / `_box` for the sim state, add code-drawn extras in `_underlay` / `_overlay`.
3. Swap the `reg.add(...)` line in the group file. Keep the old vector class as the fallback. Run `godot --path . res://tools/CaptureArt.tscn`
   and look at `/tmp/claude-1000/cucs_art_sheet.png` (sprite and fallback side by side); `bash tools/run_tests.sh ArtRegistry`.

### Sizes and anchors
- viewBox is 128 x 128. The anchor is the ground contact of the object, default bottom-centre `(64, 116)` (shadow ellipse at y ~ 114-118).
- `SpriteArt.box` = world px of the whole viewBox. Pick it so the object matches the sim size: barrel body ~ 2r tall (`box = 2.55 r`, r = 14),
  crate frame 20 x 20 (`box = 28`), caganer ~ 24 tall (`box = 31`). Hitboxes must still visually match.
- Pilot: `barrel`, `crate` (the medkit stays vector, the parachute is code), `caganer` (glow is code).

### SVG import scale
Godot rasterises the SVG at import (`svg/scale`). At scale 2.0 a sprite is 256 px for the 128-unit box; the biggest sprite box today is ~40 world px,
which at the max camera zoom 2.5 and a 2x window scale is 200 px, so 2.0 stays crisp. Larger props (bosses > 100 px) use 3.0 or 4.0 in their `.import`.
No runtime rasterisation: sprites load with `load()` and are cached by `SpriteArt` (a missing file is cached as null).

### SVG style rules (from the reference SVGs `assets/sprites/props/*.svg`, `docs/art_reference/ant.svg`)
- `viewBox="0 0 128 128"`, `width`/`height` 256; the object fills ~ 70-100 of the 128 units.
- Warm dark outline, 2-3 units, round joins (`#2a0d09`, `#2b1a0c`, `#0e0f12`: a very dark tint of the object's own hue, never pure black).
- Volume with linear gradients (light from the upper left) and radial gradients for round tops; a soft highlight stroke (`stroke-linecap="round"`, opacity ~ 0.35-0.6)
  on the lit edge; a few thin dark detail strokes at opacity ~ 0.5.
- A soft elliptical ground shadow (`radialGradient` black 0.45 -> 0, `ellipse` ~ rx 36-46, ry 6-7, y ~ 114-118) as the first element.
- No `<text>`, no filters (`feGaussianBlur` etc.: ThorVG does not support them), no external references, no CSS classes; plain paths, shapes and gradients.
- Palette consistent with the reference: saturated warm midtones (reds `#a63427`-`#d4543c`, woods `#c08a52`-`#7a4f2a`, cream `#f6f1e6`), metal greys `#6b7480`-`#9aa3ad`, gold `#f3c66f`.

## Contact sheet and tests
- `godot --path . res://tools/CaptureArt.tscn` (needs a display) writes `/tmp/claude-1000/cucs_art_sheet.png`: every kind with a sample state, sprite
  and vector fallback side by side, labelled with its id and group; kinds that need a live sim state are listed as text.
- `tests/test_art_registry.gd`: all `ART_KINDS` resolve, sprite fallback works, the pilot sprites load, every sample draws without errors.
- Give a new art a `sample_state()` so it shows up on the sheet and in the draw test.
