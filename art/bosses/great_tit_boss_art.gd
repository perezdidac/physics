## La Mallerenga (the great tit boss, art key "great_tit"): a big menacing cutout-rig bird, side view facing right (mirrored by `facing`).
## Same poses as the old BirdArt: perched (hops, wings folded: the vulnerable window), flying (wing flaps), warn (hover + "!"), dive (wings
## swept back, speed streaks), fall (tumbling, dizzy), hurt flash and knocked-out eye. Parts: assets/sprites/bosses/great_tit/.
class_name GreatTitBossArt
extends BossRigArt

## Viewbox units per old BirdArt unit, and extra size of the boss over the old drawing.
const UNIT: float = 2.6
const GROW: float = 1.12
const BODY_C := Vector2(64.0, 64.0)
const EYE_VB := Vector2(93.4, 46.4)


func _init(p_fallback: ThingArt = null) -> void:
	super(p_fallback)
	rig = BossRig.new("bosses", "great_tit", 128.0 / UNIT * GROW, BODY_C)
	rig.add_part("tail", Vector2(46.0, 66.0))
	rig.add_part("wing_far", Vector2(60.0, 56.0))
	rig.add_part("legs", Vector2(64.0, 82.0))
	rig.add_part("body")
	rig.add_part("wing_fold", Vector2(60.0, 60.0))
	rig.add_part("wing", Vector2(60.0, 56.0))
	rig.add_part("beak_low", Vector2(100.0, 57.0))
	rig.add_part("head", Vector2(80.0, 56.0))
	_sample = sample_fighter("GREAT_TIT_BOSS", 22.0, "approach")
	rig.box = 128.0 / UNIT * GROW * (22.0 / 13.0)


func sample_extent() -> Vector2:
	return Vector2(70.0, 60.0)


func _draw_rig(ci: CanvasItem, f: Variant, ctx: ArtContext) -> void:
	var t: float = ctx.t
	var st: String = BirdArt.state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 22.0)
	var s: float = r / 13.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	rig.box = 128.0 / UNIT * GROW * s
	var kk: float = rig.k()
	var rot: float = 0.0
	var flap: float = 0.0
	var wing_ang: float = 0.05
	var tail_a: float = 0.12
	var folded: bool = false
	match st:
		BirdArt.PERCHED:
			var ph: float = fmod(seed_t * 1.1, 2.4)
			c.y -= sin(ph / 0.5 * PI) * 4.5 * s if ph < 0.5 else 0.0
			c.y += r - (101.0 - BODY_C.y) * kk
			folded = true
			rot = -0.1 + sin(seed_t * 2.0) * 0.04
			tail_a = 0.3 + sin(seed_t * 3.0) * 0.05
		BirdArt.WARN:
			c.y += sin(seed_t * 9.0) * 1.0
			flap = sin(seed_t * 34.0)
			rot = -0.2
		BirdArt.DIVE:
			rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.3, 1.25) if vel.length() > 20.0 else 0.8
			wing_ang = 0.12
			tail_a = 0.02
		BirdArt.FALL:
			rot = seed_t * 11.0
			flap = sin(seed_t * 22.0) * 0.8
		_:
			flap = sin(seed_t * 26.0)
			rot = clampf(vel.y * 0.0016, -0.4, 0.4)
			tail_a = 0.15 + vel.y * 0.0004
	if ViewUtil.gb(f, "drowning"):
		c.y += 5.0
	if st == BirdArt.DIVE:
		BirdArt._trail(ci, c, vel, facing, s)
	var root := Transform2D(rot * facing, Vector2(facing, 1.0), 0.0, c)
	rig.set_pose("tail", tail_a)
	if folded:
		rig.hide("wing")
		rig.hide("wing_far")
		rig.set_pose("wing_fold", sin(seed_t * 2.0) * 0.015)
		rig.set_pose("legs", 0.0)
	else:
		rig.hide("wing_fold")
		rig.hide("legs")
		rig.set_pose("wing", wing_ang + flap * 0.95)
		rig.set_pose("wing_far", wing_ang - 0.25 + flap * 0.95)
	var open: bool = st == BirdArt.DIVE or st == BirdArt.WARN or hurt > 0.0
	rig.set_pose("beak_low", 0.38 + sin(t * 24.0) * 0.06 if open else 0.0)
	rig.set_pose("head", sin(seed_t * 3.0) * 0.02 + (0.1 if st == BirdArt.DIVE else 0.0))
	rig.draw(ci, root, BODY_C)
	hurt_flash(ci, root, Vector2(30.0, 22.0) * kk * 0.85, hurt)
	if hurt > 0.2 or st == BirdArt.FALL:
		ko_eye(ci, root, rig.pt(EYE_VB), 4.2 * kk, Color("#fbfaf2"), Color("#10131c"))
	if st == BirdArt.WARN:
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -(r + 14.0) - 4.0 * s), seed_t)
	if st == BirdArt.FALL:
		for q in 3:
			var a2: float = t * 6.5 + float(q) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 15.0 * s, -22.0 * s + sin(a2) * 4.0), 2.2, ViewColors.h("#ffe066") if q % 2 == 0 else Color.WHITE)
