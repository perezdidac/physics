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
## Nose-up tilt (rad) of a walking critter along the slope or wall it is on (negative = nose down, 0 = flat); the ant art leans by it.
var climb: float = 0.0
## Six trailing body segments.
var segs: PackedVector2Array = PackedVector2Array()
var body_colors: Array[Color] = []
var dorsal_color: Color = Color.WHITE
var individual_hat: String = "CATALAN"
var has_mustache: bool = false
var last_knock_time: float = 0.0
## "CATERPILLAR" in classic matches, else the id of `unit` (EGG, ANT...).
var kind: String = "CATERPILLAR"
## Story-mode unit stats; null for the classic caterpillars.
var unit: UnitDef = null
## Birds: in the air under its own power (no gravity). Any knockback, explosion or fall clears it; the bird takes off again on its next turn.
var flying: bool = false
## FLYER AI state the view can draw: "idle", "approach", "warn" (hovering, about to dive), "dive", "return" or "fall" (knocked down).
var ai_state: String = "idle"
## Birds: the point (in the air) it returns to after an attack.
var perch: Vector2 = Vector2.ZERO
## Story mode: tucked in a hiding spot, so the enemy CPU does not see it.
var hidden: bool = false
## Status effects (status id -> turns left), e.g. "PARASITE"; ticked at the start of the fighter's turns (SimStatus).
var statuses: Dictionary = {}

## La Processó (CONVOY levels, docs/procession_contracts.md): the first of the squad, the only one the player (or the CPU) moves.
var is_leader: bool = false
## A follower knocked more than SimConvoy.LOST_DIST px away from the line: it stays where it is until the leader walks back to it.
var lost: bool = false
## Place in the file: 0 = the leader, 1.. = the followers in the line from front to back, -1 = lost, dead or not in a convoy.
var line_index: int = -1


## True for an environmental hazard that cannot be hurt or pushed (the wild boar).
func is_hazard() -> bool:
	return unit != null and not unit.killable


## Walking speed multiplier (1 for caterpillars).
func speed_mult() -> float:
	return 1.0 if unit == null else unit.speed_mult


## False for units that cannot jump (the egg).
func can_jump() -> bool:
	return unit == null or unit.can_jump
