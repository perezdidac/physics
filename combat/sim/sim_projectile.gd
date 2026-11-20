## A shell, grenade, bomblet, biscuit or similar flying object (JS projectile object).
class_name SimProjectile
extends RefCounted

## BAZOOKA, URTICARIA, CARQUINYOLI, GRENADE, CLUSTER, HOLY, DYNAMITE or BOMBLER.
var type: String = "BAZOOKA"
var x: float = 0.0
var y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var r: float = 5.5
var wind_factor: float = 0.0
var bounces: bool = false
var bounces_left: int = 0
var blast_r: float = 0.0
var max_dmg: float = 0.0
var knockback: float = 0.0
var age: float = 0.0
var has_fuse: bool = false
var fuse: float = 0.0
var last_sec: int = 0
var choir_played: bool = false
var clusters: int = 0
## Render hint: spin angle.
var ang: float = 0.0
var is_urticating: bool = false
var is_galet: bool = false
var is_fuet_slice: bool = false
## Last 14 positions (render hint).
var trail: PackedVector2Array = PackedVector2Array()
var whistled: bool = false
var last_web_bounce: float = 0.0
var last_fighter_hit: float = 0.0
