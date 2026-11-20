# CUCS — Game bible

Only **decisions already taken** go here. Ideas and open questions go to `roadmap.md` and `pending_decisions.md`.

## 1. Concept
- Turn-based artillery game in the style of *Worms*.
- The player's units are pine processionary caterpillars (*Thaumetopoea pityocampa*), organised in squads.
- Battles take place on Catalan landscapes with destructible terrain and wind.
- Tone: humour rooted in Catalan culture (weapon and battle-cry names like "Tasta el fuet de Vic!"), affectionate, never mean.

## 2. Platform and technology
- Godot 4.7, GDScript, GL Compatibility renderer.
- Primary target: web browser (desktop and mobile, landscape). Then Android.
- Languages: English (base) and Catalan.

## 3. Modes
- **Phase 1 (port):** the modes of the original game: quick match against the CPU, 2 local players (hot seat), and custom match (places, difficulty, hats, names and faces).
- **Later (decided direction, details pending):**
  - **Story mode:** a map of levels (Candy Crush style) along a path across Catalonia, following the real life cycle of the processionary (egg → larva L1–L5 → winter silk nest → spring procession → pupa underground → moth). Rising difficulty, RPG-style upgrades and abilities unlocked level by level.
  - **Free mode:** classic Worms-style matches between animal factions based on the real enemies of the processionary.

## 4. Real enemies of the processionary (source for factions and levels)
| Stage | Real enemies |
|---|---|
| Egg | Ants; parasitoid wasps (*Ooencyrtus pityocampae*, *Baryscapus servadeii*) |
| Larva | Great tit (*Parus major*, main predator, used for biological control), blue tit, tachinid fly (*Phryxe caudata*) |
| Winter nest | Common cuckoo (eats hairy caterpillars); forestry workers |
| Procession | *Calosoma sycophanta* (caterpillar-hunting beetle), wild boar, fungus *Beauveria bassiana* |
| Pupa | Hoopoe (*Upupa epops*, digs up pupae) |
| Moth | Bats, nightjars, pheromone traps |

Which of these become levels, bosses or playable factions is **not decided yet**.

## 5. Art and animation
- Caterpillars are animated procedurally (chain of segments), as in the original.
- Enemy creatures (later phases): 3D models (Meshy AI) rendered to 2D sprite sheets, or another 2D pipeline. Not decided.
