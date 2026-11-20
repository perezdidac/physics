# Screens

## Phase 1 (port of the original)
To be filled from `port_inventory_view.md`: splash, main menu (quick match / 2 players / custom), rotate-device overlay, custom match setup (mode, difficulty, number of caterpillars, map, names), combat with top and bottom HUD, victory screen.

## Target structure (later phases)
```
Splash
└─ Main menu
   ├─ STORY
   │  └─ Campaign map (path across Catalonia, 5 seasons)
   │     ├─ The Nest (upgrade tree, moults, equip abilities)
   │     └─ Level info (goal, enemies, wind, stars)
   │        └─ Preparation (squad + abilities)
   │           └─ COMBAT ──(pause / options)
   │              └─ Results (stars, XP, loot, unlocks) → Campaign map
   ├─ FREE MODE
   │  └─ Match setup (factions, map, rules, CPU / 2 players)
   │     └─ COMBAT → Results → Rematch / Main menu
   ├─ Bestiary
   └─ Options · Credits
```
COMBAT is one single screen for both modes; it receives a `CombatSetup` describing the match.
