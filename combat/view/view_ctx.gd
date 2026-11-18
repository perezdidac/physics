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
var terrain: Object = null
var is_charging: bool = false
var charge_power: float = 0.0
var aim_angle: float = 0.0
var aim_pitch: float = -0.42
var weapon_id: String = "BAZOOKA"
var weapon_type: String = "CHARGE"
var weapon_wind_factor: float = 1.0
var spotlight_timer: float = 0.0
var has_acted: bool = false
var map_id: String = "MONTSERRAT"
var human_turn: bool = true
var view_size: Vector2 = Vector2(1280, 720)
var scale_px: float = 1.0
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
	spotlight_timer = ViewUtil.gf(sim, "turn_spotlight_timer")
	has_acted = ViewUtil.gb(sim, "has_acted_or_moved_this_turn")


## Custom face image of a fighter (lobby upload) or null.
func face_of(f: Variant) -> Variant:
	var team: int = ViewUtil.gi(f, "team")
	var idx: int = ViewUtil.gi(f, "member_idx")
	if team < custom_faces.size() and custom_faces[team] is Array and idx < (custom_faces[team] as Array).size():
		return custom_faces[team][idx]
	return ViewUtil.g(f, "custom_face_img")
