## Per-frame facts the drawing code needs (so draw functions receive what they use, not the whole sim).
class_name ViewCtx
extends RefCounted

var t_now: float = 0.0
var wind: float = 0.0
var water_y: float = 700.0
var phase: int = 0
var playing: bool = true
var active: Variant = null
var team_hats: Array = ["CATALAN", "BANDOLER"]
## Uploaded faces from the lobby: [team][member_idx] -> Image or null.
var custom_faces: Array = []
var mouse_world: Vector2 = Vector2(1600, 360)
var fighters: Array = []
var projectiles: Array = []
var mines: Array = []
## Story mode: needle-tuft positions (egg centres) and the distance from an egg centre down to the ground.
var hiding_spots: Array = []
var spot_ground_dy: float = 10.0
## Story mode: the active team has no weapon at all, so there is nothing to aim.
var no_weapons: bool = false
## Story WAVES levels: the anthill base on the surface (`has_anthill` false = none; the sim reports INF), waves left and the time (`t_now`) the last wave came out.
var has_anthill: bool = false
var anthill_pos: Vector2 = Vector2.ZERO
var waves_left: int = -1
var wave_time: float = -100.0
var terrain: Object = null
## Boss levels: the boss fighter (null = no boss), its BossDef, state ("RESTING"...), phase, announced intent and whether it takes full damage.
var boss: Variant = null
var boss_def: Variant = null
var boss_state: String = ""
var boss_phase: int = 0
var boss_intent: Dictionary = {}
var boss_vulnerable: bool = false
## El Bolsó levels: the nest (SimBolso, null = none), its area, HP fraction (1 = whole), whether it fell, the cold, the pole band and its state.
var nest: Variant = null
var nest_rect: Rect2 = Rect2()
var nest_frac: float = 1.0
var nest_destroyed: bool = false
var cold_active: bool = false
var pole_band: Rect2 = Rect2()
var pole_state: String = ""
## La Processó levels: the convoy (the leader, the line of team 0 head to tail, the march walk left in px, the goal x (-1 = none) and the
## fungus clouds). `line` has the leader first, then the followers by their place in the file; lost ones are in it too (see ConvoyInfo).
var convoy: bool = false
var leader: Variant = null
var line: Array = []
var march_left: float = 0.0
var march_budget: float = 0.0
var goal_x: float = -1.0
var goal_half: float = 90.0
var spores: Array[Rect2] = []
## The wild boars' announced charges ({boar, band: Rect2, side, turns_left}).
var boar_intents: Array = []
## Y of the ground of the goal zone (sim.goal_y; 0 = look it up in the terrain).
var goal_y: float = 0.0
## Seconds left of the spore damage pulse (ProcFx sets it; 0 = none).
var spore_pulse: float = 0.0
## Levels of the second pass (SimGoals): the rule, the goal ground (the branch of REACH, the cocoon of the sister of RESCUE; Vector2.ZERO = none),
## the nuts of COLLECT still lying on the map, and the anthill's HP fraction (-1 = it cannot be destroyed).
var goal_kind: String = ""
var goal_pos: Vector2 = Vector2.ZERO
var goal_radius: float = 60.0
var goal_nuts: Array[Vector2] = []
var anthill_frac: float = -1.0
var is_charging: bool = false
var charge_power: float = 0.0
var aim_angle: float = 0.0
var aim_pitch: float = -0.42
var weapon_id: String = "BAZOOKA"
var weapon_type: String = "CHARGE"
var weapon_wind_factor: float = 1.0
var spotlight_timer: float = 0.0
## False hides the aiming guides (direction line, trajectory, elevation badge): the touch MOVE phase. Set by the screen.
var aim_shown: bool = true
var has_acted: bool = false
var map_id: String = "MONTSERRAT"
var human_turn: bool = true
var view_size: Vector2 = Vector2(1280, 720)
var scale_px: float = 1.0
## Centre of the camera in world px (the overlays keep their labels clear of the HUD).
var cam_pos: Vector2 = Vector2(1600, 400)
var flash_light: float = 0.0
var flash_pos: Vector2 = Vector2.ZERO

const PH_TURN_PLAY: int = 0
const PH_RETREAT: int = 1
const PH_ACTION_WAIT: int = 2
const PH_TURN_DELAY: int = 3
const PH_GAME_OVER: int = 4

## Fills the fields from a CombatSim (duck-typed) for the current frame.
func read_sim(sim: Object, t: float) -> void:
	t_now = t
	var terr: Variant = ViewUtil.g(sim, "terrain")
	terrain = terr
	water_y = ViewUtil.gf(terr, "water_y", 700.0)
	wind = ViewUtil.gf(sim, "wind", 0.0)
	phase = ViewUtil.gi(sim, "turn_phase", 0)
	playing = ViewUtil.gb(sim, "playing", true)
	active = ViewUtil.g(sim, "active_fighter")
	fighters = ViewUtil.g(sim, "fighters", [])
	projectiles = ViewUtil.g(sim, "projectiles", [])
	mines = ViewUtil.g(sim, "mines", [])
	hiding_spots = ViewUtil.g(sim, "hiding_spots", [])
	no_weapons = lv_none(sim)
	var ah: Variant = ViewUtil.g(sim, "anthill_pos")
	has_anthill = ah is Vector2 and (ah as Vector2).is_finite()
	anthill_pos = ah if has_anthill else Vector2.ZERO
	var waves: int = ViewUtil.gi(sim, "waves_left", -1)
	if waves_left >= 0 and waves >= 0 and waves < waves_left:
		wave_time = t
	waves_left = waves
	var lv: Variant = ViewUtil.g(sim, "level")
	spot_ground_dy = ViewUtil.gf(ViewUtil.g(lv, "player_unit"), "radius", 10.0)
	var mw: Variant = ViewUtil.g(sim, "mouse_world")
	if mw is Vector2:
		mouse_world = mw
	is_charging = ViewUtil.gb(sim, "is_charging")
	charge_power = ViewUtil.gf(sim, "charge_power")
	aim_angle = ViewUtil.gf(sim, "aim_angle")
	aim_pitch = ViewUtil.gf(sim, "aim_pitch", -0.42)
	# Weapon data comes from the sim's WeaponDef list (data/weapons); the defaults above apply without one.
	var wi: int = ViewUtil.gi(sim, "selected_weapon_idx", 0)
	var wl: Variant = ViewUtil.g(sim, "weapons", [])
	if wi >= 0 and wl.size() > wi and wl[wi] != null:
		weapon_id = ViewUtil.gs(wl[wi], "id", weapon_id)
		weapon_type = ViewUtil.gs(wl[wi], "type", weapon_type)
		weapon_wind_factor = ViewUtil.gf(wl[wi], "wind_factor", weapon_wind_factor)
	_read_boss(sim)
	_read_nest(sim)
	_read_convoy(sim)
	StoryGoalArt.read(self, sim)
	spotlight_timer = ViewUtil.gf(sim, "turn_spotlight_timer")
	has_acted = ViewUtil.gb(sim, "has_acted_or_moved_this_turn")


## True in a story level when the active team's arsenal is empty.
static func lv_none(sim: Object) -> bool:
	if ViewUtil.g(sim, "level") == null or not sim.has_method("team_arsenal"):
		return false
	return (sim.call("team_arsenal", ViewUtil.gi(sim, "active_team")) as Array).is_empty()


## Custom face image of a fighter (lobby upload) or null.
func face_of(f: Variant) -> Variant:
	var team: int = ViewUtil.gi(f, "team")
	var idx: int = ViewUtil.gi(f, "member_idx")
	if team < custom_faces.size() and custom_faces[team] is Array and idx < (custom_faces[team] as Array).size():
		return custom_faces[team][idx]
	return ViewUtil.g(f, "custom_face_img")


func _read_boss(sim: Object) -> void:
	boss = ViewUtil.g(sim, "boss")
	boss_def = ViewUtil.g(sim, "boss_def")
	boss_state = ViewUtil.gs(sim, "boss_state")
	boss_phase = ViewUtil.gi(sim, "boss_phase")
	var intent: Variant = ViewUtil.g(sim, "boss_intent", {})
	boss_intent = intent if intent is Dictionary else {}
	var vul: Variant = ViewUtil.g(boss_def, "vulnerable_states", [])
	boss_vulnerable = boss != null and vul is Array and (vul as Array).has(boss_state)


func _read_nest(sim: Object) -> void:
	nest = ViewUtil.g(sim, "nest")
	if nest != null:
		var n_pos: Vector2 = ViewUtil.pos(ViewUtil.g(nest, "pos", Vector2.ZERO))
		var n_size: Variant = ViewUtil.g(nest, "size", Vector2(170.0, 110.0))
		nest_rect = Rect2(n_pos - (n_size as Vector2) * 0.5, n_size)
		nest_frac = clampf(ViewUtil.gf(nest, "hp") / maxf(1.0, ViewUtil.gf(nest, "max_hp", 1.0)), 0.0, 1.0)
		nest_destroyed = ViewUtil.gb(nest, "destroyed")
	cold_active = ViewUtil.gb(sim, "cold_active")
	var band: Variant = ViewUtil.g(sim, "pole_band")
	pole_band = band if band is Rect2 else Rect2()
	pole_state = ViewUtil.gs(sim, "pole_state")


## True when the fighter stands inside the nest (sheltered from the cold).
func in_nest(f: Variant) -> bool:
	return nest != null and not nest_destroyed and nest_rect.has_point(ViewUtil.pos(f))


func _read_convoy(sim: Object) -> void:
	ConvoyInfo.read(self, sim)


## Walk-cycle phase the art uses for `f`: the convoy keeps the followers wiggling in step behind the leader.
func walk_of(f: Variant) -> float:
	return ConvoyInfo.walk_of(self, f)


## True when `f` is a follower knocked away from the line (it looks worried).
func is_lost(f: Variant) -> bool:
	return convoy and ViewUtil.gb(f, "lost")
