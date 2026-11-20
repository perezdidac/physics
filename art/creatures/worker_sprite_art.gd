## The forestry worker (kind FORESTRY_WORKER) as a cut-out rig (assets/sprites/creatures/worker/): two legs that walk, a torso with hi-vis vest, head with
## ear and nose, orange helmet, far and near arm, hand and the branch-cutting pole that rests on the shoulder and swings down on a strike (poses from
## ForestryArt._pole_pose). Blink, eye brow, smile, shadow, hit tint and the drowning water are code. The foreman / WINDED poses stay in ForestryArt
## (draw_foreman, used by bosses_group.gd).
class_name WorkerSpriteArt
extends CritterSpriteArt

const BOX: float = 72.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(64.0, 70.0)


func _init() -> void:
	var r := CreatureRig.new("worker", BOX)
	r.add_instance("leg_0", "leg", _px(0.0, 3.0))
	r.add_instance("leg_1", "leg", _px(0.0, 3.0))
	r.add_instance("arm_far", "arm", _px(0.0, 0.0))
	r.add_part("torso")
	r.add_part("head")
	r.add_part("helmet")
	r.add_instance("arm_near", "arm", _px(0.0, 0.0))
	r.add_part("hand", _px(0.0, 0.0))
	r.add_part("pole", _px(0.0, 0.0))
	var sample := {"x": 0.0, "y": -12.0, "r": 12.0, "facing": 1.0, "id": 1, "kind": "FORESTRY_WORKER"}
	super(r, CritterVectorArt.new("forestry", sample, Vector2(50, 50)), sample)


static func _px(x: float, y: float) -> Vector2:
	return ANCHOR + Vector2(x, y) * U


## Poses a part whose pivot sits at world px `at`(its own rest place) so that the pivot lands on `to`.
func _place(part: String, at: Vector2, to: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	rig.set_pose(part, rot, (to - at) * U, sc)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var r: float = ViewUtil.gf(f, "r", 12.0)
	var u: float = r / 12.0
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var hurt: float = clampf(ViewUtil.gf(f, "hurt_timer"), 0.0, 1.0)
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var moving: bool = absf(ViewUtil.gf(f, "vx")) > 6.0 or ViewUtil.gb(f, "walking")
	var swing: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r * 0.5 if drowning else 0.0))
	var bob: float = absf(sin(walk * 0.5)) * 0.8 if moving else sin(t * 2.2 + float(ViewUtil.gi(f, "id"))) * 0.35
	var root := Transform2D(0.0, Vector2(facing * u, u), 0.0, origin)
	ci.draw_set_transform_matrix(root)
	ArtKit.fill_ellipse(ci, Vector2(0.0, 12.4), 9.0, 1.6, Color(0.0, 0.0, 0.0, 0.2))
	rig.reset_poses()
	rig.modulate = Color(1.0, 1.0 - hurt * 0.35, 1.0 - hurt * 0.4)
	for side in 2:
		var ph: float = walk + (PI if side == 1 else 0.0)
		var dx: float = sin(ph) * (4.0 if moving else 0.5) + (float(side) - 0.5) * 2.0
		var lift: float = maxf(0.0, cos(ph)) * (2.5 if moving else 0.0)
		var hip := Vector2((float(side) - 0.5) * 3.2, 3.0 - bob)
		_place("leg_%d" % side, Vector2(0.0, 3.0), hip + Vector2(0.0, 0.0), -dx / 9.0 + (float(side) - 0.5) * 0.0, Vector2(1.0, 1.0 - lift / 18.0))
		if side == 0:
			rig.set_part_tint("leg_0", Color(0.8, 0.8, 0.8))
	var up := Vector2(0.0, -bob * U)
	rig.set_pose("torso", 0.0, up)
	rig.set_pose("head", 0.0, up)
	rig.set_pose("helmet", 0.0, up)
	# arms: far hangs and swings, near holds the pole
	var pole: Dictionary = ForestryArt._pole_pose(f, swing, false, vc)
	var fs := Vector2(-1.5, -5.0 - bob)
	var fv := Vector2(-4.5 + sin(walk) * 2.0, 1.0 - bob) - fs
	_place("arm_far", Vector2.ZERO, fs, atan2(-fv.x, fv.y), Vector2(1.0, fv.length() / 8.0))
	rig.set_part_tint("arm_far", Color(0.75, 0.75, 0.75))
	var ns := Vector2(2.0, -5.5 - bob)
	var hand: Vector2 = pole["hand"]
	var nv: Vector2 = hand - ns
	_place("arm_near", Vector2.ZERO, ns, atan2(-nv.x, nv.y), Vector2(1.0, nv.length() / 8.0))
	_place("hand", Vector2.ZERO, hand)
	_place("pole", Vector2.ZERO, hand, float(pole["angle"]))
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var c := Vector2(1.4, -13.2 - bob)
	var blink: bool = fmod(t * 0.8 + float(ViewUtil.gi(f, "id")) * 1.7, 4.5) > 4.38
	var eye := c + Vector2(2.6, -0.8)
	if blink:
		ci.draw_line(eye + Vector2(-1.4, 0.0), eye + Vector2(1.4, 0.0), ForestryArt.INK, 1.0, true)
	else:
		ci.draw_circle(eye, 1.5, Color.WHITE)
		ci.draw_circle(eye + Vector2(0.5, 0.1), 0.85, ForestryArt.INK)
		ci.draw_line(eye + Vector2(-1.8, -2.2), eye + Vector2(1.8, -1.9), ForestryArt.INK, 1.0, true)
	ci.draw_arc(c + Vector2(3.0, 2.4), 1.9, 0.2, PI - 0.3, 6, ForestryArt.INK, 0.9, true)
	if drowning:
		ci.draw_rect(Rect2(-14.0, 4.0, 28.0, 14.0), Color(0.3, 0.55, 0.75, 0.55))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
