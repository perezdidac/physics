## The small tachinid fly as a cut-out rig (assets/sprites/creatures/fly/): bristly abdomen with the ovipositor (out when it warns or dives),
## grey thorax, big red compound eye on the head, two see-through wings (buzzing with ghost images, folded when perched, swept back in a dive)
## and legs (dangling in flight, standing when perched). The pose comes from BirdArt.state like FlyArt; hurt cross, fierce brow, hit flash, "!" bubble
## and dizzy stars are code.
class_name FlySpriteArt
extends CritterSpriteArt

const BOX: float = 48.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(64.0, 64.0)
const BASE_R: float = 11.0


func _init() -> void:
	var r := CreatureRig.new("fly", BOX)
	r.add_part("legs_stand")
	for k in 3:
		r.add_part("leg%d" % k, _px(-2.0 + float(k) * 4.2, 3.0))
	r.add_instance("wing_far", "wing", _px(1.5, -4.6))
	r.add_part("ovi_in", _px(-16.5, 2.8))
	r.add_part("ovi_out", _px(-16.5, 2.8))
	r.add_part("abdomen")
	r.add_part("thorax")
	r.add_instance("wing_ghost_a", "wing", _px(1.5, -4.6))
	r.add_instance("wing_ghost_b", "wing", _px(1.5, -4.6))
	r.add_instance("wing_near", "wing", _px(1.5, -4.6))
	r.add_part("head")
	var sample := {"x": 0.0, "y": -4.0, "r": 11.0, "facing": 1.0, "id": 1, "ai_state": "approach", "flying": true}
	super(r, CritterVectorArt.new("fly", sample, Vector2(44, 30)), sample)


static func _px(x: float, y: float) -> Vector2:
	return ANCHOR + Vector2(x, y) * U


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var st: String = BirdArt.state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", BASE_R)
	var s: float = r / BASE_R
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.7
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	var rot: float = 0.0
	var buzz: float = 1.0
	var legs_down: float = 0.0
	match st:
		BirdArt.PERCHED:
			buzz = 0.0
			legs_down = 1.0
			c.y += sin(seed_t * 2.4) * 0.5 * s
		BirdArt.WARN:
			c.y += sin(seed_t * 11.0) * 1.2
			rot = 0.25
		BirdArt.DIVE:
			rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.5, 1.3) if vel.length() > 20.0 else 0.9
		BirdArt.FALL:
			rot = seed_t * 10.0
		_:
			c.y += sin(seed_t * 5.0) * 2.0 * s
			rot = clampf(vel.y * 0.0012, -0.3, 0.3)
	if drowning:
		c.y += 5.0
	if st == BirdArt.DIVE:
		BirdArt._trail(ci, c, vel, facing, s)
	var root := Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning)
	rig.set_visible_part("legs_stand", legs_down > 0.0)
	for k in 3:
		rig.set_visible_part("leg%d" % k, legs_down <= 0.0)
		rig.set_pose("leg%d" % k, sin(seed_t * 6.0 + float(k) * 1.3) * 0.12 - (0.3 if st == BirdArt.DIVE else 0.0))
	var out: bool = st == BirdArt.WARN or st == BirdArt.DIVE
	rig.set_visible_part("ovi_out", out)
	rig.set_visible_part("ovi_in", not out)
	# wings: the sprite points back (-x); rotation = old angle - PI
	var ang: float = _wing_rot(st, seed_t, buzz)
	var far_rot: float = ang - 0.25 if buzz > 0.0 else ang + 0.07
	rig.set_pose("wing_near", ang)
	rig.set_pose("wing_far", far_rot)
	rig.set_part_tint("wing_far", Color(1, 1, 1, 0.7))
	var ghosts: bool = buzz > 0.0 and st != BirdArt.DIVE
	rig.set_visible_part("wing_ghost_a", ghosts)
	rig.set_visible_part("wing_ghost_b", ghosts)
	rig.set_pose("wing_ghost_a", ang - 0.55)
	rig.set_pose("wing_ghost_b", ang + 0.55)
	rig.set_part_tint("wing_ghost_a", Color(1, 1, 1, 0.3))
	rig.set_part_tint("wing_ghost_b", Color(1, 1, 1, 0.3))
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var line: Color = ViewColors.h("#0c0d10")
	var hc := Vector2(10.4, -0.4)
	if hurt > 0.2:
		ci.draw_line(hc + Vector2(-0.8, -2.8), hc + Vector2(2.4, -0.2), line, 1.2, true)
		ci.draw_line(hc + Vector2(2.4, -2.8), hc + Vector2(-0.8, -0.2), line, 1.2, true)
	elif out:
		ci.draw_line(hc + Vector2(-1.8, -4.6), hc + Vector2(3.6, -2.6), line, 1.5, true)
	hurt_flash(ci, Vector2.ZERO, 14.0, 9.0, hurt)
	water_wash(ci, Vector2.ZERO, 14.0, 9.0, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == BirdArt.WARN:
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -24.0 * s), seed_t)
	if st == BirdArt.FALL:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 13.0 * s, -18.0 * s + sin(a2) * 4.0), 2.0, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)


## Rotation of the wing sprite (which points backwards) for the old wing angle `PI + x`.
static func _wing_rot(st: String, t: float, buzz: float) -> float:
	if buzz <= 0.0:
		return 0.06
	if st == BirdArt.DIVE:
		return 0.35
	return 0.3 + (0.5 + 0.5 * sin(t * 58.0)) * 0.95
