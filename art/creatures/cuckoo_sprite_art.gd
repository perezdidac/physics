## The cuckoo (boss of the Processó stage) as a cut-out rig (assets/sprites/creatures/cuckoo/): graduated white-dotted tail, grey wings (flapping leaf
## wings or folded), slim barred body or the round sated one, head with curved beak, legs when sated. States come from ViewCtx.boss_state like
## CuckooArt (flying, INTENT hover, ACT dive, SATED). Eye (ring, happy arc, hurt cross, fierce brow), hit flash, trail, "!" and "z" bubbles are code.
## Registered as "creature:CUCKOO"; CuckooArt.draw delegates here and keeps the old drawing as `draw_vector`.
class_name CuckooSpriteArt
extends CritterSpriteArt

const BOX: float = 64.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(64.0, 64.0)


func _init() -> void:
	var r := CreatureRig.new("cuckoo", BOX)
	r.add_part("legs")
	r.add_part("tail", _px(-10.0, 0.6))
	r.add_part("wing_far", _px(-1.0, -3.0))
	r.add_part("wing_fold_far")
	r.add_part("body")
	r.add_part("body_sated")
	r.add_part("wing_near", _px(-1.0, -3.0))
	r.add_part("wing_fold_near")
	r.add_part("head")
	var sample := {"x": 0.0, "y": -4.0, "r": 22.0, "facing": 1.0, "id": 1}
	super(r, CritterVectorArt.new("cuckoo", sample, Vector2(90, 50)), sample)


static func _px(x: float, y: float) -> Vector2:
	return ANCHOR + Vector2(x, y) * U


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var st: String = vc.boss_state
	var sated: bool = st == "SATED"
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 22.0)
	var s: float = r / 14.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	var flap: float = 0.0
	var rot: float = 0.0
	var fold: float = 0.0
	if sated:
		c.y += r - 15.0 * s + sin(seed_t * 1.6) * 0.8
		fold = 1.0
		rot = -0.05
	elif st == "ACT":
		rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.3, 1.2) if vel.length() > 20.0 else 0.7
		fold = 0.8
		CuckooArt._trail(ci, c, vel, facing, s)
	elif st == "INTENT":
		c.y += sin(seed_t * 9.0)
		flap = sin(seed_t * 30.0)
		rot = -0.15
	else:
		flap = sin(seed_t * 18.0)
		rot = clampf(vel.y * 0.0012, -0.3, 0.3)
	if drowning:
		c.y += 5.0
	var root := Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning)
	var folded: bool = fold >= 0.75
	rig.set_visible_part("legs", sated)
	rig.set_visible_part("body", not sated)
	rig.set_visible_part("body_sated", sated)
	rig.set_visible_part("wing_far", not folded)
	rig.set_visible_part("wing_near", not folded)
	rig.set_visible_part("wing_fold_far", folded and not sated)
	rig.set_visible_part("wing_fold_near", folded)
	rig.set_pose("tail", (0.22 if sated else 0.06 + sin(seed_t * 2.0) * 0.03))
	if not folded:
		var ang: float = -0.9 - flap * 0.9
		rig.set_pose("wing_near", ang)
		rig.set_pose("wing_far", ang - 0.35)
	else:
		var wy: float = -4.6 if fold >= 1.0 else -1.4
		var place := Vector2(0.0, (wy - 0.0) * U)
		rig.set_pose("wing_fold_near", -0.12 if fold < 1.0 else 0.0, place)
		rig.set_pose("wing_fold_far", -0.12, place)
	var hy: float = -2.4 if sated else 0.0
	rig.set_pose("head", 0.0, Vector2(0.0, hy * U))
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var hc := Vector2(12.0, -7.0 if sated else -4.6)
	var eye: Vector2 = hc + Vector2(1.8, -1.0)
	var line: Color = CuckooArt.LINE
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-1.4, -1.4), eye + Vector2(1.4, 1.4), line, 1.3, true)
		ci.draw_line(eye + Vector2(1.4, -1.4), eye + Vector2(-1.4, 1.4), line, 1.3, true)
	elif sated:
		ci.draw_arc(eye + Vector2(0.0, 0.6), 1.9, PI * 1.1, PI * 1.9, 8, line, 1.4, true)
		ArtKit.fill_ellipse(ci, hc + Vector2(0.8, 2.2), 1.7, 1.0, Color(1.0, 0.5, 0.5, 0.5))
	else:
		ci.draw_circle(eye, 3.0, CuckooArt.EYE_RING)
		ci.draw_circle(eye, 1.8, Color("#0d0f14"))
		ci.draw_circle(eye + Vector2(-0.4, -0.5), 0.5, Color.WHITE)
		if st == "ACT" or st == "INTENT":
			ci.draw_line(eye + Vector2(-3.0, -3.2), eye + Vector2(2.8, -1.6), line, 1.6, true)
	hurt_flash(ci, Vector2.ZERO, 16.0, 9.0, hurt)
	water_wash(ci, Vector2.ZERO, 16.0, 9.0, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == "INTENT":
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -30.0 * s), seed_t)
	elif sated:
		CuckooArt._zzz(ci, c + Vector2(facing * 6.0 * s, -22.0 * s), seed_t)
