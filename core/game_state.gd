## Global game state: the settings of the match being set up or played (lobby choices kept between screens).
## Fields and `make_match_config()` follow docs/port_contracts.md section 4.
extends Node

const MODES: Array[String] = ["1P_CPU", "2P_LOCAL", "CPU_CPU"]
const DIFFICULTIES: Array[String] = ["ROOKIE", "VETERAN", "NIGHTMARE"]
const HAT_OPTIONS: Array[String] = ["VARIED", "CATALAN", "CASTELLER", "BANDOLER", "PAGES", "BRISTLES"]
const MAP_COUNT := 8
const MAX_WORMS := 6
const MATCH_CONFIG_PATH := "res://combat/sim/match_config.gd"

## Original name pools (state.js CATALAN_NAMES_POOL_0/1). Proper nouns, not translated; the DATA agent may move them to data/names.tres.
const NAME_POOL_0: Array[String] = [
	"Peluda", "Serrallonga", "Pinassa", "Rovelló", "Botifarra", "Calçot",
	"Gaudí", "Garbí", "Fuet", "Escudella", "Barretina", "Porró",
	"Senyera", "Caganer", "Timbaler", "Casteller", "Enxaneta", "Gralla",
	"Sardana", "Ginesta", "Romaní", "Pinyó", "Llobregat", "Montseny",
	"Carquinyoli", "Crema", "Allioli", "Romesco", "Cargol", "Bolets",
]
const NAME_POOL_1: Array[String] = [
	"Urticària", "Tramuntana", "Boira", "Espina", "Tió", "Fageda",
	"Ratafia", "Empordà", "Canigó", "Pedraforca", "Bruixa", "Drac",
	"Correfoc", "Diable", "Mestral", "Xaloc", "Llevant", "Pissarra",
	"Basalt", "Cingle", "Falç", "Trabuc", "Bandoler", "Gorg",
	"Albera", "Cadí", "Priorat", "Batea", "Lo Riu", "Garrotxa",
]

var game_mode: String = "1P_CPU"
var ai_difficulty: String = "VETERAN"
var worms_per_team: int = 4
var map_idx: int = 0
var team_hats: Array[String] = ["CATALAN", "BANDOLER"]
## Two arrays of 6 names (index = team, then caterpillar).
var team_names: Array = [
	["Peluda", "Serrallonga", "Pinassa", "Rovelló", "Botifarra", "Calçot"],
	["Urticària", "Tramuntana", "Boira", "Espina", "Ratafia", "Canigó"],
]
## Two arrays of 6 entries: an Image (uploaded face) or null.
var custom_faces: Array = [[null, null, null, null, null, null], [null, null, null, null, null, null]]
var has_custom_names: bool = false
## True once a match was started from the menus (shows "back to current match" in the lobby).
var has_started_match: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	randomize_names()


## Fills `team_names` with 6 random names per team from the pools (JS randomizeSquadNames).
func randomize_names() -> void:
	var p0: Array[String] = NAME_POOL_0.duplicate()
	var p1: Array[String] = NAME_POOL_1.duplicate()
	_shuffle(p0)
	_shuffle(p1)
	for i in MAX_WORMS:
		team_names[0][i] = p0[i].strip_edges()
		team_names[1][i] = p1[i].strip_edges()


## Prepares a quick match (menu items 0 and 1): random hats and map, random names.
func prepare_quick_match(mode: String) -> void:
	game_mode = mode
	has_custom_names = false
	team_hats[0] = HAT_OPTIONS[_rng.randi_range(0, HAT_OPTIONS.size() - 1)]
	team_hats[1] = HAT_OPTIONS[_rng.randi_range(0, HAT_OPTIONS.size() - 1)]
	map_idx = _rng.randi_range(0, MAP_COUNT - 1)
	has_started_match = true


## Builds the MatchConfig for the current choices. Returns a MatchConfig when combat/sim/match_config.gd exists, else a Dictionary with the same fields.
func make_match_config() -> Variant:
	if not has_custom_names:
		randomize_names()
	var names: Array = []
	for t in 2:
		var row: Array = []
		for i in worms_per_team:
			row.append(team_names[t][i])
		names.append(row)
	var values: Dictionary = {
		"map_idx": map_idx,
		"game_mode": game_mode,
		"ai_difficulty": ai_difficulty,
		"worms_per_team": worms_per_team,
		"team_names": names,
		"team_hats": team_hats.duplicate(),
		"custom_faces": custom_faces,
		"seed": 0,
	}
	if ResourceLoader.exists(MATCH_CONFIG_PATH):
		var script: GDScript = load(MATCH_CONFIG_PATH)
		var cfg: Variant = script.new()
		for key: String in values:
			if key in cfg:
				cfg.set(key, values[key])
		return cfg
	return values


func _shuffle(arr: Array[String]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
