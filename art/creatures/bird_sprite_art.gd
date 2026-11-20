## The blue tit and the great tit of the Pelussa stage as cut-out rigs (assets/sprites/creatures/bluetit|greattit/): tail, two wings (open leaf
## wings that flap, or folded ones), olive back and yellow belly, a head (blue cap or black head with white cheek), upper and lower beak and the
## perched legs. Poses come from BirdArt.state / velocity (perched hops, flying flaps, warn hover, dive tilt with trail, fall tumble); eye,
## hurt cross, fierce brow, hit flash, the "!" bubble and dizzy stars are code. Scales with the fighter radius (r / 13) like BirdArt.
class_name BirdSpriteArt
extends CritterSpriteArt

const BOX: float = 48.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(64.0, 64.0)

var great: bool = false


func _init(p_great: bool = false) -> void:
	great = p_great
	var r := CreatureRig.new("greattit" if p_great else "bluetit", BOX)
	r.add_part("legs")
	r.add_part("tail", _px(-5.0, 1.6))
	r.add_part("wing_far", _px(-1.0, -2.0))
	r.add_part("wing_fold_far")
	r.add_part("body")
	r.add_part("wing_near", _px(-1.0, -2.0))
	r.add_part("wing_fold_near")
	r.add_part("head")
	r.add_part("beak_low")
	r.add_part("beak_up")
	var sample := {"x": 0.0, "y": -4.0, "r": 13.0, "facing": 1.0, "id": 1, "kind": "GREAT_TIT" if p_great else "BLUE_TIT", "ai_state": "approach", "flying": true}
	super(r, CritterVectorArt.new("bird", sample, Vector2(50, 40)), sample)


static func _px(x: float, y: float) -> Vector2:
	return ANCHOR + Vector2(x, y) * U


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var st: String = BirdArt.state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 13.0)
	var s: float = r / 13.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	var rot: float = 0.0
	var flap: float = 0.0
	var fold: float = 0.0
	match st:
		BirdArt.PERCHED:
			var ph: float = fmod(seed_t * 1.1, 2.4)
			c.y -= sin(ph / 0.5 * PI) * 4.5 if ph < 0.5 else 0.0
			c.y += r - 10.5 * s
			fold = 1.0
			rot = -0.1 + sin(seed_t * 2.0) * 0.04
		BirdArt.WARN:
			c.y += sin(seed_t * 9.0) * 1.0
			flap = sin(seed_t * 34.0)
			rot = -0.2
		BirdArt.DIVE:
			rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.3, 1.25) if vel.length() > 20.0 else 0.8
			fold = 0.8
		BirdArt.FALL:
			rot = seed_t * 11.0
			flap = sin(seed_t * 22.0) * 0.8
		_:
			flap = sin(seed_t * 26.0)
			rot = clampf(vel.y * 0.0016, -0.4, 0.4)
	if drowning:
		c.y += 5.0
	if st == BirdArt.DIVE:
		BirdArt._trail(ci, c, vel, facing, s)
	var root := Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning)
	var perched: bool = st == BirdArt.PERCHED
	var folded: bool = fold >= 0.75
	rig.set_visible_part("legs", perched)
	rig.set_visible_part("wing_far", not folded and not perched)
	rig.set_visible_part("wing_near", not folded)
	rig.set_visible_part("wing_fold_far", folded and not perched)
	rig.set_visible_part("wing_fold_near", folded)
	var tail_a: float = (sin(seed_t * 3.0) * 0.05 if perched else 0.0) - fold * 0.1
	rig.set_pose("tail", tail_a)
	if not folded:
		var ang: float = -0.9 - flap * 0.85
		rig.set_pose("wing_near", ang)
		rig.set_pose("wing_far", ang - 0.35)
	elif fold < 1.0:
		rig.set_pose("wing_fold_near", -0.12, Vector2(-3.0, -0.6) * U)
		rig.set_pose("wing_fold_far", -0.12, Vector2(-3.0, -0.6) * U)
	var open: bool = st == BirdArt.DIVE or st == BirdArt.WARN
	rig.set_visible_part("beak_low", open)
	rig.set_pose("beak_up", 0.0, Vector2(0.0, -0.8 * U) if open else Vector2.ZERO)
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var line: Color = ViewColors.h("#10131c") if great else ViewColors.h("#14213d")
	var hc := Vector2(8.6, -5.0)
	var eye: Vector2 = hc + Vector2(1.6, -0.4)
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-1.2, -1.2), eye + Vector2(1.2, 1.2), line, 1.2, true)
		ci.draw_line(eye + Vector2(1.2, -1.2), eye + Vector2(-1.2, 1.2), line, 1.2, true)
	else:
		if great:
			ci.draw_circle(eye, 2.3, Color.WHITE)
		ci.draw_circle(eye, 1.7, ViewColors.h("#0d0f14"))
		ci.draw_circle(eye + Vector2(-0.4, -0.5), 0.5, Color.WHITE)
		if open:
			ci.draw_line(eye + Vector2(-2.6, -2.8), eye + Vector2(2.4, -1.5), line, 1.5, true)
	hurt_flash(ci, Vector2.ZERO, 12.0, 9.0, hurt)
	water_wash(ci, Vector2.ZERO, 12.0, 9.0, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == BirdArt.WARN:
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -26.0 * s), seed_t)
	if st == BirdArt.FALL:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 13.0, -20.0 + sin(a2) * 4.0), 2.0, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)
