## Settings of one match, handed to CombatSim.setup().
class_name MatchConfig
extends RefCounted

## Index into data/maps/map_list.tres.
var map_idx: int = 0
## "1P_CPU", "2P_LOCAL" or "CPU_CPU".
var game_mode: String = "1P_CPU"
## "ROOKIE", "VETERAN" or "NIGHTMARE".
var ai_difficulty: String = "VETERAN"
var worms_per_team: int = 4
## [[names of team 0], [names of team 1]]; empty means "pick random names".
var team_names: Array = []
var team_hats: Array = ["CATALAN", "BANDOLER"]
## Story level; null for the classic modes (which must behave exactly as before).
var level: LevelDef = null
## Story: weapons added to the player's arsenal on top of LevelDef.player_arsenal (weapon id -> ammo, -1 = unlimited).
## GameState fills it from the weapons unlocked so far; the sim never reads autoloads.
var extra_arsenal: Dictionary = {}
## Story: ids of the upgrades the player owns (StoryProgress.owned_upgrades()); the sim applies them to story matches only.
var upgrades: Array[String] = []
## RNG seed; 0 = random.
@warning_ignore("shadowed_global_identifier")
var seed: int = 0
