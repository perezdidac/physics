## Minimal stand-in for CombatSim used by the HUD preview and the UI tests: same property names and signals as the contract.
class_name HudFakeSim
extends RefCounted

signal hud_changed
signal wind_changed
signal turn_started(team: int, fighter: Variant)
signal game_over(winner: int, stats: Dictionary)

var fighters: Array = []
var active_fighter: Variant = null
var active_team: int = 0
var turn_phase: int = 0
var turn_timer: float = 24.0
var phase_timer: float = 0.0
var round_number: int = 3
var wind: int = 42
var wind_float: float = 42.0
var wind_target: float = 80.0
var wind_gust_flash: float = 0.0
var team_ammo: Array = []
var selected_weapon_idx: int = 0
var custom_grenade_fuse: int = 3
var is_charging: bool = false
var charge_power: float = 0.0
var has_acted_or_moved_this_turn: bool = false
var winner: int = -1
var team_damage_dealt: Array = [120, 95]
var ai_turn: bool = false
## Names of the commands received, in order (for tests).
var calls: Array[String] = []


func _init() -> void:
	var names: Array = [["Peluda", "Serrallonga", "Pinassa", "Rovelló"], ["Urticària", "Tramuntana", "Boira", "Espina"]]
	for t in 2:
		for i in 4:
			fighters.append({"team": t, "name": names[t][i], "hp": 100.0 - 17.0 * i, "max_hp": 100.0, "alive": i != 3, "drowning": false, "dmg_dealt": 10.0 * (i + t), "grounded": true})
	active_fighter = fighters[0]
	for t in 2:
		team_ammo.append({"BAZOOKA": INF, "CARQUINYOLI": INF, "GRENADE": INF, "CLUSTER": 3, "URTICARIA": 3, "SHOTGUN": INF, "FUET": INF, "BAT": INF, "DYNAMITE": 0, "HOLY": 1, "AIRSTRIKE": 2, "JETPACK": 2, "CULLERA": 3, "BARRINA": 3, "PONT_PEDRA": 3, "GANXO": 3})


func is_current_turn_ai() -> bool:
	return ai_turn


func select_weapon(idx: int) -> bool:
	calls.append("select_weapon:%d" % idx)
	selected_weapon_idx = idx
	return true


func set_fuse(seconds: int) -> void:
	calls.append("set_fuse:%d" % seconds)
	custom_grenade_fuse = seconds


func set_move(dir: int) -> void:
	calls.append("set_move:%d" % dir)


func set_aim_input(dir: int) -> void:
	calls.append("set_aim_input:%d" % dir)


func jump_forward() -> void:
	calls.append("jump_forward")


func jump_backward() -> void:
	calls.append("jump_backward")


func begin_charge_or_fire() -> void:
	calls.append("begin_charge_or_fire")


func release_charge() -> void:
	calls.append("release_charge")


func switch_fighter() -> void:
	calls.append("switch_fighter")
