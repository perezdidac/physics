## The tachinid fly boss (art key "tachinid_fly"): a big bristly grey-black fly facing right (mirrored by `facing`), huge red compound eyes,
## see-through buzzing wings and a red ovipositor. Poses from the sim's `ai_state` like the old FlyArt: hover / fly (blurred wings, legs dangling),
## warn (ovipositor out, "!"), dive (tilted, wings back, streaks), rest (landed on its legs, wings folded: vulnerable), fall (tumbling, dizzy).
## Parts: assets/sprites/bosses/tachinid_fly/.
class_name TachinidFlyBossArt
extends BossRigArt

const UNIT: float = 3.2
const GROW: float = 1.08
const BODY_C := Vector2(66.0, 66.0)
const EYE_VB := Vector2(100.0, 60.0)
const WING_ROOT := Vector2(71.0, 52.0)
const OVI_ROOT := Vector2(17.0, 72.0)


func _init(p_fallback: ThingArt = null) -> void:
	super(p_fallback)
	rig = BossRig.new("bosses", "tachinid_fly", 128.0 / UNIT * GROW, BODY_C)
	rig.add_part("legs_hang")
	rig.add_part("legs_stand")
	rig.add_part("wing_far", WING_ROOT)
	rig.add_part("ovi", OVI_ROOT)
	rig.add_part("abdomen", Vector2(46.0, 66.0))
	rig.add_part("thorax")
	rig.add_part("wing", WING_ROOT)
	rig.add_part("head", Vector2(86.0, 64.0))
	_sample = sample_fighter("TACHINID_FLY", 16.0, "warn")


func sample_extent() -> Vector2:
	return Vector2(60.0, 50.0)


func _draw_rig(ci: CanvasItem, f: Variant, ctx: ArtContext) -> void:
	var t: float = ctx.t
	var st: String = BirdArt.state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 16.0)
	var s: float = r / FlyArt.BASE_R
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.7
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	rig.box = 128.0 / UNIT * GROW * s
	var kk: float = rig.k()
	var rot: float = 0.0
	var buzz: bool = true
	match st:
		BirdArt.PERCHED:
			buzz = false
			c.y += r - (106.0 - BODY_C.y) * kk + sin(seed_t * 2.4) * 0.5 * s
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
	if ViewUtil.gb(f, "drowning"):
		c.y += 5.0
	if st == BirdArt.DIVE:
		BirdArt._trail(ci, c, vel, facing, s)
	var root := Transform2D(rot * facing, Vector2(facing, 1.0), 0.0, c)
	var wing_a: float = 0.06
	if buzz:
		wing_a = 0.35 if st == BirdArt.DIVE else 0.3 + (0.5 + 0.5 * sin(seed_t * 58.0)) * 0.95
	var out: bool = st == BirdArt.WARN or st == BirdArt.DIVE
	if buzz:
		rig.hide("legs_stand")
		rig.set_pose("legs_hang", sin(seed_t * 6.0) * 0.05)
	else:
		rig.hide("legs_hang")
		rig.set_pose("legs_stand", 0.0)
	rig.set_pose("wing", wing_a)
	rig.set_pose("wing_far", wing_a - 0.25 if buzz else wing_a + 0.07)
	rig.set_pose("ovi", 0.0 if out else -1.1, Vector2.ZERO, Vector2.ONE if out else Vector2(0.55, 0.55))
	rig.set_pose("abdomen", sin(seed_t * 3.0) * 0.015)
	var warn_head: float = 0.06 if out else 0.0
	rig.set_pose("head", warn_head)
	rig.draw(ci, root, BODY_C)
	if buzz and st != BirdArt.DIVE:
		# motion blur: two translucent ghosts of the flapping wing
		for g in [-0.55, 0.55]:
			rig.set_pose("wing", wing_a + g)
			rig.draw_mod(ci, root, Color(1.0, 1.0, 1.0, 0.35), ["wing"])
	hurt_flash(ci, root, Vector2(40.0, 24.0) * kk * 0.8, hurt)
	if hurt > 0.2 or st == BirdArt.FALL:
		ko_eye(ci, root, rig.pt(EYE_VB), 5.0 * kk, Color("#d8252b"), Color("#0c0d10"))
	if st == BirdArt.WARN:
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -(r + 14.0)), seed_t)
	if st == BirdArt.FALL:
		for q in 3:
			var a2: float = t * 6.5 + float(q) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 15.0 * s, -20.0 * s + sin(a2) * 4.0), 2.2, ViewColors.h("#ffe066") if q % 2 == 0 else Color.WHITE)
