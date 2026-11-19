## The ant enemy as a cut-out rig: abdomen, thorax, head, two antennae, two mandibles and six legs (tripod gait) from
## assets/sprites/creatures/ant/. Eyes, blink, hurt crosses and the red hit flash are code. Same fields and sizes as AntArt.
class_name AntSpriteArt
extends CritterSpriteArt

const BOX: float = 32.0
const CENTRE := Vector2(64.0, 64.0)
const U: float = 4.0 ## viewBox units per world px (128 / BOX)
const BODY_PARTS: Array[String] = ["abdomen", "thorax", "head"]
const LEGS: Array[String] = ["f", "m", "r"]
## Hip x offset (px) and stride direction per leg pair, as in AntArt.
const HIP_X: Array[float] = [3.0, 0.0, -3.0]


func _init() -> void:
	var r := CreatureRig.new("ant", BOX)
	for leg in LEGS:
		r.add_part("leg_%s_far" % leg, _hip(leg))
	r.add_part("antenna_b", Vector2(97, 50))
	r.add_part("abdomen")
	r.add_part("thorax")
	for leg in LEGS:
		r.add_part("leg_%s_near" % leg, _hip(leg))
	r.add_part("head")
	r.add_part("mandible_down", Vector2(100, 62))
	r.add_part("mandible_up", Vector2(100, 62))
	r.add_part("antenna_a", Vector2(97, 50))
	super(r, CritterVectorArt.new("ant", {"x": 0.0, "y": -9.0, "r": 9.0, "walk_cycle": 0.0, "facing": 1.0, "grounded": true, "id": 0}, Vector2(40, 30)))


static func _hip(leg: String) -> Vector2:
	match leg:
		"f": return Vector2(76, 64)
		"m": return Vector2(64, 64)
	return Vector2(52, 64)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", -1.0)
	var r: float = ViewUtil.gf(f, "r", 9.0)
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var bite: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var bob: float = absf(sin(walk * 0.5)) * 0.9 if grounded else 0.0
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r - 4.0 if drowning else 0.0))
	var rot: float = ViewUtil.gf(f, "flip_angle") - facing * ViewUtil.gf(f, "climb")
	var root := Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0), ViewUtil.gf(f, "squash_y", 1.0)), 0.0, origin)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning)
	var up := Vector2(0.0, -bob * U)
	for p in BODY_PARTS:
		rig.set_pose(p, 0.0, up)
	# legs: tripod gait, stride swings the leg about its hip, lift raises the foot
	var ground: float = r - 0.3
	var reach: float = ground + 0.4
	for i in 3:
		for side in 2:
			var ph: float = walk + (PI if (i + side) % 2 == 0 else 0.0)
			var stride: float = sin(ph) * 3.4
			var lift: float = maxf(0.0, cos(ph)) * 2.4 + (0.0 if grounded else 3.0)
			var part: String = "leg_%s_%s" % [LEGS[i], "near" if side == 0 else "far"]
			rig.set_pose(part, -stride / reach, Vector2(0.0, -lift * U))
	rig.set_pose("mandible_up", 0.0, up)
	rig.set_pose("mandible_down", 0.0, up)
	var open: float = 0.55 + sin(t * 4.0) * 0.08
	if bite > 0.0:
		open = 1.1 if bite > 0.7 else 0.0
	rig.set_pose("mandible_up", -open * 0.5, up)
	rig.set_pose("mandible_down", open * 0.5, up)
	var seed_x: float = ViewUtil.gf(f, "x") * 0.05
	rig.set_pose("antenna_a", sin(t * 5.0 + seed_x) * 0.1, up)
	rig.set_pose("antenna_b", sin(t * 5.0 + seed_x + 1.7) * 0.12, up)
	rig.draw(ci, root, CENTRE)
	# code on top: eye (blink, hurt cross) and the red hit flash
	ci.draw_set_transform_matrix(root)
	var by: float = -1.0 - bob
	var line: Color = ArtKit.hex("#2b100a")
	var blink: bool = fmod(t * 0.7 + float(ViewUtil.gi(f, "id")) * 2.1, 5.0) > 4.88
	if hurt > 0.2:
		ci.draw_line(Vector2(5.0, by - 2.6), Vector2(7.2, by - 0.6), line, 1.2, true)
		ci.draw_line(Vector2(7.2, by - 2.6), Vector2(5.0, by - 0.6), line, 1.2, true)
	elif blink:
		ci.draw_line(Vector2(5.2, by - 1.6), Vector2(7.4, by - 1.6), line, 1.1, true)
	else:
		ArtKit.fill_ellipse(ci, Vector2(6.3, by - 1.6), 1.2, 1.5, ArtKit.hex("#0b0605"))
		ci.draw_circle(Vector2(5.9, by - 2.0), 0.5, Color(1, 1, 1, 0.9))
	hurt_flash(ci, Vector2(-1.5, by), 12.0, 5.5, hurt)
	water_wash(ci, Vector2(-1.5, by), 13.0, 6.0, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
