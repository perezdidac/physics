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
## RNG seed; 0 = random.
@warning_ignore("shadowed_global_identifier")
var seed: int = 0
