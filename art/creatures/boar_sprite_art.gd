## The wild boar (senglar) as a cut-out rig (assets/sprites/creatures/boar/): two pairs of short legs that gallop when it charges, a deep fur barrel
## with a bristle mane, a wagging tail tuft and a head with snout disc and ivory tusks. Poses, bob, dust trail and nostril steam follow BoarArt;
## the eye (frown, red pupil while charging, hurt cross) is code. The warning band stays in BoarArt.draw_warning.
class_name BoarSpriteArt
extends CritterSpriteArt

const BOX: float = 112.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(50.0, 104.0)
const LEG_PIVOT := Vector2(64.0, 50.0)
const FAR_X: Array[float] = [-13.0, 22.0]
const NEAR_X: Array[float] = [-21.0, 16.0]
const LIFT: float = -4.5


func _init() -> void:
	var r := CreatureRig.new("boar", BOX)
	for i in 2:
		r.add_instance("leg_far_%d" % i, "leg_far", LEG_PIVOT)
	r.add_part("tail", ANCHOR + Vector2(-28.0, -26.0 + LIFT) * U)
	r.add_part("rump")
	r.add_part("body")
	r.add_part("mane", ANCHOR + Vector2(-10.0, -34.0 + LIFT) * U)
	for i in 2:
		r.add_instance("leg_near_%d" % i, "leg_near", LEG_PIVOT)
	r.add_part("head")
	var sample := {"x": 0.0, "y": -20.0, "r": 20.0, "facing": 1.0, "id": 1, "kind": "WILD_BOAR"}
	super(r, CritterVectorArt.new("boar", sample, Vector2(100, 70)), sample)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var r: float = ViewUtil.gf(f, "r", 20.0)
	var s: float = r / 20.0
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	if facing == 0.0:
		facing = 1.0
	var charging: bool = BoarArt.phase(f) == BoarArt.CHARGE
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var feet := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + r)
	var run: float = t * (22.0 if charging else 4.0) + float(ViewUtil.gi(f, "id"))
	if charging:
		BoarArt._dust(ci, feet, facing, s, t)
	var bob: float = (absf(sin(run)) * 2.6 * s) if charging else sin(run) * 0.5
	var root := Transform2D(0.0, Vector2(facing * s, s), 0.0, feet + Vector2(0.0, -bob))
	rig.reset_poses()
	rig.modulate = Color.WHITE
	for far in [true, false]:
		var xs: Array[float] = FAR_X if far else NEAR_X
		for i in 2:
			var ph: float = run + float(i) * PI + (0.0 if far else PI * 0.5)
			var sw: float = sin(ph) * (9.0 if charging else 1.5)
			var lift: float = maxf(0.0, cos(ph)) * (6.0 if charging else 0.0)
			var place := Vector2(xs[i], -14.0 - lift) * U - (LEG_PIVOT - ANCHOR)
			rig.set_pose("leg_%s_%d" % ["far" if far else "near", i], -sw / 14.0, place)
	var wag: float = sin(run * 0.8) * 3.0
	rig.set_pose("tail", wag / 12.0)
	rig.set_pose("mane", sin(t * 9.0) * 0.012)
	rig.set_pose("head", 0.0, Vector2(0.0, 4.0 * U) if charging else Vector2.ZERO)
	rig.draw(ci, root, ANCHOR)
	# eye, brow and steam in the lifted head space
	ci.draw_set_transform_matrix(root * Transform2D(0.0, Vector2(0.0, LIFT)))
	var line: Color = BoarArt.FUR_DARK
	var c := Vector2(28.0, -22.0 + (4.0 if charging else 0.0))
	var eye: Vector2 = c + Vector2(6.0, -4.0)
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-2.0, -2.0), eye + Vector2(2.0, 2.0), line, 1.8, true)
		ci.draw_line(eye + Vector2(2.0, -2.0), eye + Vector2(-2.0, 2.0), line, 1.8, true)
	else:
		ci.draw_circle(eye, 3.0, Color("#f7ecd8"))
		ci.draw_circle(eye + Vector2(0.8, 0.0), 1.9, Color("#a8261c") if charging else Color("#1a1210"))
		ci.draw_circle(eye + Vector2(0.2, -0.8), 0.6, Color.WHITE)
	ci.draw_line(eye + Vector2(-4.0, -5.0), eye + Vector2(4.5, -1.6), line, 2.6, true)
	if charging:
		for k in 2:
			var ph2: float = fmod(t * 3.0 + float(k) * 0.5, 1.0)
			ci.draw_circle(c + Vector2(28.0 + ph2 * 10.0, 3.0 - ph2 * 6.0), 2.0 + ph2 * 3.0, Color(1.0, 1.0, 1.0, 0.45 * (1.0 - ph2)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
