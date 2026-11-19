## The parasitoid wasp of the platform boss level as a cutout rig (assets/sprites/bosses/wasp/): striped two-piece abdomen that curls with the state,
## a stinger, a fuzzy thorax, a big-eyed head with antennae and mandibles, dangling legs and translucent buzzing wings (blurred ghosts). The moving
## bits are code: curl, flap, wobbling antennae, pupils (red while warning, spirals while dizzy), the stinger glow. Used by PlatformBossView.
class_name WaspBossArt
extends RefCounted

const UNIT: float = 1.5
const GROW: float = 1.08
const BODY_SCALE_REF: float = 1.3
const ANCHOR := Vector2(64.0, 64.0)
const WING_ROOT := Vector2(64.0, 118.0)
const EYES: Array[Vector2] = [Vector2(4.8, -5.4), Vector2(2.7, 6.3)]
const BODY_PARTS: Array = ["legs", "abd_b", "abd_a", "thorax", "head", "ant_a", "ant_b"]

var rig: BossRig = null


func _init() -> void:
	rig = BossRig.new("bosses", "wasp", 128.0 / UNIT * BODY_SCALE_REF * GROW, ANCHOR)
	rig.add_part("wing_far", WING_ROOT)
	rig.add_part("wing", WING_ROOT)
	rig.add_part("legs", Vector2(64.0, 30.0))
	rig.add_part("abd_b", Vector2(112.0, 64.0))
	rig.add_part("abd_a", Vector2(104.0, 64.0))
	rig.add_part("thorax")
	rig.add_part("head")
	rig.add_part("ant_a", Vector2(64.0, 108.0))
	rig.add_part("ant_b", Vector2(64.0, 108.0))


func available() -> bool:
	return rig.is_complete()


static func _p(o: Vector2) -> Vector2:
	return ANCHOR + o * UNIT


## Draws one wasp. `c` world centre of the thorax, `ang` lean, `facing` +-1, `scale_k` the view's BODY_SCALE, `state` PATROL/WARN/DIVE/RECOVER.
func draw(ci: CanvasItem, c: Vector2, ang: float, facing: float, scale_k: float, state: String, t: float) -> void:
	rig.box = 128.0 / UNIT * scale_k * GROW
	var kk: float = rig.k()
	var root := Transform2D(ang * facing, Vector2(facing, 1.0), 0.0, c)
	var curl: float
	match state:
		"WARN":
			curl = 0.75
		"DIVE":
			curl = 0.1
		"RECOVER":
			curl = -0.25
		_:
			curl = 0.3 + sin(t * 4.0) * 0.1
	var recover: bool = state == "RECOVER"
	# wings: the near one with two blurred ghosts, the far one behind
	var flap_speed: float = 60.0 if not recover else 18.0
	var amp: float = 0.55 if not recover else 0.3
	var lean: float = -0.35 if state == "DIVE" else -0.12
	var wscale := Vector2(0.88, 0.88)
	rig.pose_at("wing_far", _p(Vector2(-3.0, -8.0)), lean - 0.2 + sin(t * flap_speed + 2.2) * amp, wscale)
	rig.pose_at("wing", _p(Vector2(-1.0, -9.0)), lean + sin(t * flap_speed) * amp, wscale)
	rig.draw_mod(ci, root, Color.WHITE, ["wing_far", "wing"])
	for k in [1, 2]:
		rig.pose_at("wing", _p(Vector2(-1.0, -9.0)), lean + sin(t * flap_speed + float(k) * 1.1) * amp, wscale)
		rig.draw_mod(ci, root, Color(1.0, 1.0, 1.0, 0.4), ["wing"])
	# body
	rig.pose_at("legs", _p(Vector2(0.0, 6.0)), sin(t * 9.0) * 0.08, Vector2(1.0, 0.72))
	var rot_a: float = -0.15 - curl * 0.5
	var rot_b: float = -0.15 - curl * 1.2
	var joint_a: Vector2 = _p(Vector2(-10.0, 2.0))
	var joint_b: Vector2 = joint_a + Vector2(-52.0, 0.0).rotated(rot_a)
	rig.pose_at("abd_a", joint_a, rot_a)
	rig.pose_at("abd_b", joint_b, rot_b)
	rig.pose_at("thorax", ANCHOR, 0.0)
	var head_c: Vector2 = _p(Vector2(17.0, 1.0))
	rig.pose_at("head", head_c, 0.0)
	var wob: float = sin(t * 6.0) * 0.08
	rig.pose_at("ant_a", head_c + Vector2(6.0, -12.0), wob)
	rig.pose_at("ant_b", head_c + Vector2(1.5, -13.5), -wob * 1.3)
	rig.draw_mod(ci, root, Color.WHITE, BODY_PARTS)
	# pupils: look at the target while warning, red when angry, spirals when dizzy
	ci.draw_set_transform_matrix(root)
	var look := Vector2(1.0, 0.0)
	if state == "WARN":
		look = Vector2(1.2, 1.4)
	elif state == "DIVE":
		look = Vector2(1.6, 1.0)
	var pupil := Color(0.1, 0.07, 0.05)
	if state == "WARN":
		pupil = Color(0.75, 0.08, 0.08)
	for e in EYES:
		var ec: Vector2 = rig.pt(head_c + e)
		if recover:
			_spiral(ci, ec, 4.6 * kk, t)
		else:
			var pc: Vector2 = ec + look * 1.6 * kk
			ci.draw_circle(pc, 3.9 * kk, pupil)
			ci.draw_circle(pc + Vector2(-1.2, -1.6) * kk, 1.3 * kk, Color.WHITE)
	if state == "WARN":
		var tip: Vector2 = rig.pt(joint_b + Vector2(-106.0, 2.0).rotated(rot_b))
		ci.draw_circle(tip, (4.4 + sin(t * 30.0) * 1.2) * kk * 1.5, Color(1.0, 0.25, 0.2, 0.55))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _spiral(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var u: float = float(k) / 13.0
		var an: float = u * TAU * 1.6 + t * 8.0
		pts.append(c + Vector2(cos(an), sin(an)) * r * u)
	ci.draw_polyline(pts, Color(0.1, 0.07, 0.05), 1.6, true)
