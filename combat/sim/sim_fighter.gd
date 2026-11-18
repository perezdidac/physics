## One processionary caterpillar (JS fighter object, snake_case fields).
class_name SimFighter
extends RefCounted

var id: int = 0
var team: int = 0
var member_idx: int = 0
var name: String = ""
## Centre position (feet are at y + r).
var x: float = 0.0
var y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var r: float = 12.0
var hp: int = 100
var max_hp: int = 100
var alive: bool = true
var drowning: bool = false
var drown_timer: float = 0.0
var grounded: bool = false
var sliding: bool = false
var slide_angle: float = 0.0
var slide_timer: float = 0.0
var is_minor_slide: bool = false
var jump_start_x: float = 0.0
var has_jump_start_x: bool = false
var jump_start_y: float = 0.0
var peak_air_y: float = 0.0
var air_timer: float = 0.0
var is_voluntary_jump: bool = true
var was_blasted: bool = false
var flip_angle: float = 0.0
var flip_spin: float = 0.0
var metamorphosed: bool = false
var linked_allies: Array[SimFighter] = []
var castell_tower: bool = false
var pilota_buff: bool = false
var wine_tipsy: float = 0.0
var spoon_timer: float = 0.0
var spoon_angle: float = 0.0
var spoon_tick: float = 0.0
var drill_timer: float = 0.0
var drill_angle: float = 0.0
var drill_tick: float = 0.0
## Empty when no grapple is active; otherwise start_x/y, target_x/y, hook_x/y, progress.
var grapple: Dictionary = {}
var jet_fuel: float = 0.0
var bat_swing_timer: float = 0.0
var last_melee_id: String = ""
var dizzy_timer: float = 0.0
var hurt_timer: float = 0.0
var urticating_ticks: int = 0
var dmg_dealt: int = 0
var last_aim_pitch: float = -0.42
var last_charge_power: float = 0.0
var squash_x: float = 1.0
var squash_y: float = 1.0
var facing: int = 1
var walk_cycle: float = 0.0
## Six trailing body segments.
var segs: PackedVector2Array = PackedVector2Array()
var body_colors: Array[Color] = []
var dorsal_color: Color = Color.WHITE
var individual_hat: String = "CATALAN"
var has_mustache: bool = false
var last_knock_time: float = 0.0
