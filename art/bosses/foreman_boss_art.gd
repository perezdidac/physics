## El Capatàs (the brigade foreman boss, art key "foreman"): a big stern cutout-rig person facing right (mirrored by `facing`) in an orange hi-vis vest and
## white helmet, with a moustache, a clipboard and a branch-cutting pole. Same poses as the old ForestryArt foreman: standing / walking (leg swing, bob),
## the pole resting on the shoulder, raised while winding up the LINE attack and swinging down on `bat_swing_timer`, the cartridge launcher while CARTRIDGE
## is announced, and WINDED (sitting on the ground, leaning back, panting, the clipboard fanning him, sweat and breath puffs, the pole on the ground).
## Parts: assets/sprites/bosses/foreman/. Drawn in old-unit space: one old unit = UNIT viewBox units.
class_name ForemanBossArt
extends BossRigArt

const UNIT: float = 3.2
const GROW: float = 1.1
const ANCHOR := Vector2(64.0, 80.0)
const ARM_LEN: float = 46.0
const HEAD_PIVOT := Vector2(62.0, 72.0)
const POLE_PIVOT := Vector2(24.0, 64.0)


func _init(p_fallback: ThingArt = null) -> void:
	super(p_fallback)
	rig = BossRig.new("bosses", "foreman", 128.0 / UNIT * 2.0 * GROW, ANCHOR)
	rig.add_part("legs_sit", Vector2(22.0, 66.0))
	rig.add_part("leg_far", Vector2(64.0, 30.0))
	rig.add_part("arm_far", Vector2(64.0, 30.0))
	rig.add_part("leg_near", Vector2(64.0, 30.0))
	rig.add_part("launcher", Vector2(10.0, 90.0))
	rig.add_part("torso", Vector2(64.0, 86.0))
	rig.add_part("head", HEAD_PIVOT)
	rig.add_part("head_tired", HEAD_PIVOT)
	rig.add_part("clipboard", Vector2(64.0, 62.0))
	rig.add_part("arm_near", Vector2(64.0, 30.0))
	rig.add_part("pole", POLE_PIVOT)
	var f: Dictionary = sample_fighter("BRIGADE_BOSS", 20.0)
	f["walk_cycle"] = 1.0
	f["vx"] = 0.0
	f["bat_swing_timer"] = 0.0
	_sample = f


func sample_extent() -> Vector2:
	return Vector2(60.0, 80.0)


## Old unit point -> viewBox point of the rig frame.
static func _p(o: Vector2) -> Vector2:
	return ANCHOR + o * UNIT


## Points the downward-hanging arm part from `from` (viewBox) to `to`.
func _arm(part: String, from: Vector2, to: Vector2) -> void:
	var d: Vector2 = to - from
	rig.pose_at(part, from, atan2(-d.x, d.y), Vector2(1.0, clampf(d.length() / ARM_LEN, 0.5, 1.4)))


func _draw_rig(ci: CanvasItem, f: Variant, ctx: ArtContext) -> void:
	var vctx: ViewCtx = ctx.combat
	var t: float = ctx.t
	var winded: bool = boss_state(ctx) == "WINDED"
	var r: float = ViewUtil.gf(f, "r", 20.0)
	var u: float = r / 12.0 * 1.2
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var hurt: float = clampf(ViewUtil.gf(f, "hurt_timer"), 0.0, 1.0)
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var moving: bool = absf(ViewUtil.gf(f, "vx")) > 6.0 or ViewUtil.gb(f, "walking")
	var swing: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r * 0.5 if drowning else 0.0))
	var bob: float = 0.0 if winded else (absf(sin(walk * 0.5)) * 0.8 if moving else sin(t * 2.2 + float(ViewUtil.gi(f, "id"))) * 0.35)
	rig.box = 128.0 / UNIT * u * GROW
	var root := Transform2D(0.0, Vector2(facing, 1.0), 0.0, origin)
	var old_root := Transform2D(0.0, Vector2(facing * u * GROW, u * GROW), 0.0, origin)
	# ground shadow
	ci.draw_set_transform_matrix(old_root)
	ViewUtil.fill_ellipse(ci, Vector2(0.0, 12.6), 13.0, 2.0, Color(0.0, 0.0, 0.0, 0.25))
	var head_vb: Vector2
	var hand_vb: Vector2
	var blink_cover: bool = false
	if winded:
		var lean: float = -0.22 + sin(t * 7.0) * 0.03
		for part in ["leg_far", "leg_near", "launcher", "arm_far"]:
			rig.hide(part)
		rig.set_pose("head", 0.0)
		rig.hide("head")
		rig.pose_at("legs_sit", _p(Vector2(-2.0, 9.2)), 0.0, Vector2(0.62, 1.0))
		rig.pose_at("torso", _p(Vector2(-2.0, 9.4)), lean, Vector2(1.2, 1.05))
		head_vb = _p(Vector2(-5.2, -9.4 + sin(t * 7.0) * 0.7))
		rig.pose_at("head_tired", head_vb, lean * 0.6)
		var fan: float = sin(t * 11.0) * 0.5
		var clip: Vector2 = head_vb + Vector2(11.0, 3.0) * UNIT
		rig.pose_at("clipboard", clip, 0.8 + fan, Vector2(0.85, 0.85))
		_arm("arm_near", _p(Vector2(-3.4, -3.0)), clip + Vector2(-8.0, 6.0))
		rig.pose_at("pole", _p(Vector2(-12.0, 12.2)), PI)
	else:
		rig.hide("legs_sit")
		rig.hide("head_tired")
		var pole: Dictionary = ForestryArt._pole_pose(f, swing, true, vctx)
		for side in 2:
			var ph: float = walk + (PI if side == 1 else 0.0)
			var dx: float = sin(ph) * (4.0 if moving else 0.5)
			var lift: float = maxf(0.0, cos(ph)) * (2.5 if moving else 0.0)
			rig.pose_at("leg_far" if side == 0 else "leg_near", _p(Vector2((float(side) - 0.5) * 3.2, -1.2 - bob)), -atan2(dx, 11.0), Vector2(1.0, 1.0 - lift * 0.04))
		rig.pose_at("torso", _p(Vector2(-0.3, 4.6 - bob)), 0.0, Vector2(1.0, 0.92))
		head_vb = _p(Vector2(1.4, -13.2 - bob))
		rig.set_pose("head", 0.0)
		rig.pose_at("head", head_vb, 0.0)
		_arm("arm_far", _p(Vector2(-1.5, -5.0 - bob)), _p(Vector2(-4.5 + sin(walk) * 2.0, 2.0 - bob)))
		rig.pose_at("clipboard", _p(Vector2(-1.0, -1.5 - bob)), -0.12, Vector2(0.7, 0.7))
		var hold: Vector2 = pole["hand"]
		hand_vb = _p(hold + Vector2(0.0, 3.0))
		_arm("arm_near", _p(Vector2(2.0, -5.5 - bob)), hand_vb)
		rig.pose_at("pole", hand_vb, float(pole["angle"]))
		if str(vctx.boss_intent.get("attack_id", "")) == "CARTRIDGE":
			rig.pose_at("launcher", _p(Vector2(-1.0, -9.0 - bob)), 0.0)
		else:
			rig.hide("launcher")
		blink_cover = fmod(t * 0.8 + float(ViewUtil.gi(f, "id")) * 1.7, 4.5) > 4.38
	if hurt > 0.0:
		rig.draw_mod(ci, root, Color(1.0, 1.0 - hurt * 0.45, 1.0 - hurt * 0.55))
	else:
		rig.draw(ci, root, ANCHOR)
	if blink_cover:
		ci.draw_set_transform_matrix(root)
		var eye: Vector2 = rig.pt(head_vb + (Vector2(73.6, 68.4) - HEAD_PIVOT))
		ci.draw_circle(eye, 6.8 * rig.k(), Color("#f1b184"))
		ci.draw_line(eye + Vector2(-5.0, 0.0) * rig.k(), eye + Vector2(5.0, 0.0) * rig.k(), Color("#1a1410"), 2.4 * rig.k(), true)
	if winded:
		_sweat(ci, old_root, t, Vector2(-5.2, -9.4))
	if drowning:
		ci.draw_set_transform_matrix(old_root)
		ci.draw_rect(Rect2(-18.0, 4.0, 36.0, 14.0), Color(0.3, 0.55, 0.75, 0.55))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sweat drops and breath puffs around the head (old-unit space).
static func _sweat(ci: CanvasItem, old_root: Transform2D, t: float, head: Vector2) -> void:
	ci.draw_set_transform_matrix(old_root)
	for k in 3:
		var ph: float = fmod(t * 1.4 + float(k) * 0.33, 1.0)
		var d := head + Vector2(-6.0 - float(k) * 3.0 - ph * 5.0, -7.0 - ph * 6.0 + ph * ph * 20.0)
		ViewUtil.fill_poly(ci, PackedVector2Array([d + Vector2(0.0, -2.6), d + Vector2(1.5, 0.4), d + Vector2(-1.5, 0.4)]), Color(0.55, 0.82, 1.0, 1.0 - ph))
		ci.draw_circle(d + Vector2(0.0, 0.5), 1.5, Color(0.55, 0.82, 1.0, 1.0 - ph))
		var pu: float = fmod(t * 1.1 + float(k) * 0.37, 1.0)
		ci.draw_circle(head + Vector2(9.0 + pu * 8.0, 5.0 - pu * 5.0), 1.4 + pu * 2.4, Color(1.0, 1.0, 1.0, 0.65 * (1.0 - pu)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
