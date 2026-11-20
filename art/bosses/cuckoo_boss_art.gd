## El Cucut (the cuckoo boss, art key "cuckoo"): a big cutout-rig bird facing right (mirrored by `facing`), slim grey with a long dotted tail,
## long pointed wings, a barred belly and a yellow eye ring. Poses from the boss state like the old CuckooArt: flying (flaps), INTENT (hover + "!"),
## ACT (dive, streaks) and SATED (sits on its legs with a round full belly, happy shut eyes, "z" bubbles: the vulnerable window).
## Parts: assets/sprites/bosses/cuckoo/.
class_name CuckooBossArt
extends BossRigArt

const UNIT: float = 1.75
const GROW: float = 1.15
const BODY_C := Vector2(76.0, 64.0)
const EYE_VB := Vector2(101.0, 54.0)


func _init(p_fallback: ThingArt = null) -> void:
	super(p_fallback)
	rig = BossRig.new("bosses", "cuckoo", 128.0 / UNIT * GROW, BODY_C)
	rig.add_part("legs", Vector2(76.0, 80.0))
	rig.add_part("tail", Vector2(60.0, 65.0))
	rig.add_part("wing_far", Vector2(74.0, 59.0))
	rig.add_part("body")
	rig.add_part("body_sated")
	rig.add_part("wing_fold", Vector2(84.0, 60.0))
	rig.add_part("wing", Vector2(74.0, 59.0))
	rig.add_part("head", Vector2(88.0, 60.0))
	rig.add_part("head_sated", Vector2(88.0, 58.0))
	_sample = sample_fighter("CUCKOO_BOSS", 22.0, "idle")


func sample_extent() -> Vector2:
	return Vector2(90.0, 50.0)


func _draw_rig(ci: CanvasItem, f: Variant, ctx: ArtContext) -> void:
	var t: float = ctx.t
	var st: String = boss_state(ctx)
	var sated: bool = st == "SATED"
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 22.0)
	var s: float = r / 14.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	rig.box = 128.0 / UNIT * GROW * s
	var kk: float = rig.k()
	var flap: float = 0.0
	var rot: float = 0.0
	var wing_ang: float = 0.05
	var droop: float = 0.06 + sin(seed_t * 2.0) * 0.03
	var dive: bool = false
	if sated:
		c.y += r - (101.0 - BODY_C.y) * kk + sin(seed_t * 1.6) * 0.8
		rot = -0.05
		droop = 0.3
	elif st == "ACT":
		rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.3, 1.2) if vel.length() > 20.0 else 0.7
		wing_ang = 0.1
		dive = true
		droop = 0.0
		BirdArt._trail(ci, c, vel, facing, s)
	elif st == "INTENT":
		c.y += sin(seed_t * 9.0)
		flap = sin(seed_t * 30.0)
		rot = -0.15
	else:
		flap = sin(seed_t * 18.0)
		rot = clampf(vel.y * 0.0012, -0.3, 0.3)
	if ViewUtil.gb(f, "drowning"):
		c.y += 5.0
	var root := Transform2D(rot * facing, Vector2(facing, 1.0), 0.0, c)
	rig.set_pose("tail", droop)
	if sated:
		rig.hide("body")
		rig.hide("wing")
		rig.hide("wing_far")
		rig.hide("head")
		rig.set_pose("legs", 0.0)
		rig.set_pose("body_sated", 0.0)
		rig.set_pose("wing_fold", 0.0)
		rig.set_pose("head_sated", sin(seed_t * 1.6) * 0.02)
	else:
		rig.hide("body_sated")
		rig.hide("wing_fold")
		rig.hide("legs")
		rig.hide("head_sated")
		rig.set_pose("body", 0.0)
		rig.set_pose("wing", wing_ang + flap * 0.9)
		rig.set_pose("wing_far", wing_ang - 0.25 + flap * 0.9)
		rig.set_pose("head", 0.08 if dive else 0.0)
	rig.draw(ci, root, BODY_C)
	hurt_flash(ci, root, Vector2(32.0, 16.0 if not sated else 26.0) * kk * 0.8, hurt)
	if hurt > 0.2 and not sated:
		ko_eye(ci, root, rig.pt(EYE_VB), 4.2 * kk, Color("#f0c63a"), Color("#1a1f27"))
	if st == "INTENT":
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -(r + 16.0)), seed_t)
	elif sated:
		CuckooArt._zzz(ci, c + Vector2(facing * 8.0 * s, -26.0 * s), seed_t)
