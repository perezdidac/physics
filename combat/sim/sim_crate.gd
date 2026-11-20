## Supply crate (parachuting, falling or landed).
class_name SimCrate
extends RefCounted

var x: float = 0.0
var y: float = -30.0
var vx: float = 0.0
var vy: float = 55.0
var parachuting: bool = true
var grounded: bool = false
var is_medkit: bool = false
var reward_wpn: String = ""
