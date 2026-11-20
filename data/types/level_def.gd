## One story-mode level. Team 0 is always the player (human), team 1 the CPU. See docs/story_mode.md and docs/story_contracts.md.
class_name LevelDef
extends Resource

@export var id: String = ""
## Life stage: EGG, LARVA_EARLY, LARVA, NEST, PROCESSION, PUPA, MOTH.
@export var stage: String = "EGG"
## Position inside the campaign (1, 2, 3...).
@export var order: int = 1
## False: shown on the campaign map as "coming soon", cannot be started.
@export var playable: bool = true
## COMBAT (turn-based battle, CombatScreen) or PLATFORM (real-time platformer, PlatformScreen).
@export var mode: String = "COMBAT"
## Only for PLATFORM levels.
@export var layout: PlatformLayout

@export_group("Texts")
## Translation keys.
@export var title_key: String = ""
@export var intro_key: String = ""
@export var goal_key: String = ""
@export var tip_key: String = ""

@export_group("World")
## Index into data/maps/map_list.tres.
@export var map_idx: int = 0
## Background picture key for ArtCatalog.background() in COMBAT levels; "" = the map's own. PLATFORM levels use layout.background_key.
@export var background_key: String = ""
## COMBAT levels: width (px) of the playable span of the terrain; the land outside it is removed. 0 = the whole classic terrain (SimTables.TERRAIN_W).
@export var arena_width: float = 0.0
## World x of the middle of the arena; 0 = the middle of the terrain.
@export var arena_center: float = 0.0
## Fixed seed so the level is always the same terrain; 0 = random.
@warning_ignore("shadowed_global_identifier")
@export var seed: int = 0
## Number of hiding spots placed on the map.
@export var hiding_spots: int = 0
## Barrels, mines, nests, pickups and flora as in the classic match.
@export var hazards: bool = false
@export var supply_drops: bool = false
@export var tide: bool = false
## With `tide`: the first round the water starts to rise (10 in classic matches).
@export var tide_round: int = 10
@export var turn_time: float = 30.0
@export var ai_difficulty: String = "ROOKIE"
## Multiplies the random wind of every turn (1 = normal).
@export var wind_scale: float = 1.0
## Abilities of the squad in this level. "SILK_WEB": spin_silk_web() is allowed (always allowed in classic matches).
@export var abilities: Array[String] = []

@export_group("Squads")
@export var player_unit: UnitDef
## Proper names of the player's units (not translated).
@export var player_names: Array[String] = []
@export var enemy_unit: UnitDef
@export var enemy_count: int = 2
## Mixed enemy team: enemy_units[i] x enemy_counts[i]. When empty, enemy_unit x enemy_count is used.
@export var enemy_units: Array[UnitDef] = []
@export var enemy_counts: Array[int] = []
## Weapon id → ammo (-1 = unlimited). Weapons not listed are not available.
@export var player_arsenal: Dictionary = {}
@export var enemy_arsenal: Dictionary = {}
## True: the player's arsenal also gets every weapon unlocked by the levels won so far (GameState adds them to MatchConfig.extra_arsenal).
@export var use_unlocked: bool = true
## Boss of the level (team 1, acts last in the enemy turn); null for levels without one. See docs/boss_contracts.md.
@export var boss: BossDef

@export_group("Goal")
## ELIMINATE, REACH, RESCUE, COLLECT, ONE_SHOT (see "Goal (levels 2)" below), SURVIVE_ROUNDS, BOSS (defeat `boss`; the other enemies do not count), WAVES (an anthill sends `wave_size` ants at the start of each enemy turn for `survive_rounds` rounds; surviving the last round wins)
## DEFEND_NEST (survive `survive_rounds` rounds with the nest standing; the nest at 0 HP loses; see docs/nest_contracts.md),
## CONVOY (the squad is a procession: the leader reaches `goal_x`; it dies and the level is lost; see docs/procession_contracts.md)
## or BOSS_OR_GOAL (a CONVOY level whose boss can also be defeated instead of reaching the goal).
@export var win_rule: String = "SURVIVE_ROUNDS"
@export var survive_rounds: int = 4
## WAVES: world x of the anthill (the nearest ground to it is used) and ants per wave (spawned from `enemy_unit`).
@export var anthill_x: float = 2300.0
@export var wave_size: int = 2
## El Bolsó: HP of the silk nest of the level (0 = no nest). Any win rule can have one (the BOSS level of the stage does): the nest at 0 HP loses.
@export var nest_hp: int = 0
## El Bolsó: caterpillars outside the nest lose HP at the start of their turn (WARM_SILK cancels it).
@export var cold: bool = false
## El Bolsó: a forestry pole sweeps a telegraphed vertical band every 2 rounds.
@export var pole: bool = false
@export_group("Goal (levels 2)")
## REACH (a caterpillar stands within `goal_radius` of the branch), RESCUE (a caterpillar reaches the trapped sister: she joins and the level is won),
## COLLECT (gather `collect_need` of the `collect_count` pine nuts lying on the map) and ONE_SHOT (kill the sheltered enemy with the limited
## arsenal). All four lose when `survive_rounds` rounds (0 = no limit) are over, and also win when every enemy is down.
## REACH / RESCUE: world x of the spot (0 = `goal_frac` of the way across the arena); the nearest ground the squad can walk to is used.
## `goal_radius` is shared with the convoy.
@export var goal_frac: float = 0.85
## COLLECT: pine nuts placed on the map, and how many must be gathered.
@export var collect_count: int = 0
@export var collect_need: int = 0
## WAVES: HP of the anthill (0 = indestructible). Explosions hurt it; at 0 HP the level is won.
@export var anthill_hp: int = 0
## Explosive barrels placed by the level: next to the enemies (ELIMINATE) or round the anthill (WAVES). Proximity mines between the squads.
@export var barrels: int = 0
@export var mines: int = 0
## ONE_SHOT: the enemies never move and are placed behind cover (a ridge between them and the squad).
@export var enemy_still: bool = false
@export_group("Convoy")
## CONVOY / BOSS_OR_GOAL: the leader wins by standing within `goal_radius` px of this world x (soft soil to bury in).
@export var goal_x: float = 0.0
@export var goal_radius: float = 80.0
## Walking budget (px) of the leader each turn.
@export var march_budget: float = 420.0
## Beauveria spore clouds (world rects), and how far each one drifts sideways every round (px, may be negative; missing = 0).
@export var spores: Array[Rect2] = []
@export var spore_drift: Array[float] = []
## WILD_BOAR charges: boar i announces its charge at the enemy turn of round boar_rounds[i] and charges at the next one.
@export var boar_rounds: Array[int] = []
## CONVOY: id of an enemy unit (e.g. "CALOSOMA") whose defeat also wins the level.
@export var mini_boss: String = ""

@export_group("Rewards")
## Survivors needed for 2 and 3 stars (1 star = level won). A convoy counts the leader and the followers still in the line.
@export var star_survivors: Array[int] = [2, 3]
## Weapon ids unlocked when this level is won (shown on the results screen).
@export var unlocks: Array[String] = []


## Every enemy unit of the starting team, in spawn order (mixed teams first, else enemy_unit x enemy_count).
func enemy_roster() -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	if enemy_units.is_empty():
		for i in (enemy_count if enemy_unit != null else 0):
			out.append(enemy_unit)
		return out
	for i in enemy_units.size():
		for j in (enemy_counts[i] if i < enemy_counts.size() else 1):
			out.append(enemy_units[i])
	return out


## True when the level lists the ability (e.g. "SILK_WEB").
func has_ability(ability: String) -> bool:
	return abilities.has(ability)


## True for the rules of the procession (CONVOY and BOSS_OR_GOAL): one leader, the others follow it.
func is_convoy() -> bool:
	return win_rule == "CONVOY" or win_rule == "BOSS_OR_GOAL"


## True for the rules with a round limit (`survive_rounds`, 0 = none) that are lost when it runs out.
func is_timed_goal() -> bool:
	return win_rule == "REACH" or win_rule == "RESCUE" or win_rule == "COLLECT" or win_rule == "ONE_SHOT"
