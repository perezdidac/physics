## The Calosoma beetle (caterpillar hunter) as a cut-out rig (assets/sprites/creatures/calosoma/): six long legs that scissor with the walk
## cycle, metallic green elytra with a copper rim and golden pits, a gold pronotum, a dark head, two snapping mandibles and two antennae.
## Eye, hurt flash and tilt are code. Same fields and sizes as CalosomaArt (scale r / 12, facing mirror, flip_angle).
class_name CalosomaSpriteArt
extends CritterSpriteArt

const BOX: float = 64.0
const U: float = 128.0 / BOX
const ANCHOR := Vector2(64.0, 64.0)
const BODY: Array[String] = ["elytra", "pronotum", "head", "mandible_down", "mandible_up", "antenna_a", "antenna_b"]


func _init() -> void:
	var r := CreatureRig.new("calosoma", BOX)
	for k in 3:
		r.add_part("leg%d_far" % k, _hip(k))
	for k in 3:
		r.add_part("leg%d_near" % k, _hip(k))
	r.add_part("elytra")
	r.add_part("pronotum")
	r.add_part("head")
	r.add_part("mandible_down", _px(17.0, -7.9))
	r.add_part("mandible_up", _px(17.0, -7.9))
	r.add_part("antenna_a", _px(17.0, -11.5))
	r.add_part("antenna_b", _px(17.0, -11.5))
	var sample := {"x": 0.0, "y": -12.0, "r": 12.0, "walk_cycle": 0.0, "facing": 1.0, "grounded": true, "id": 0}
	super(r, CritterVectorArt.new("calosoma", sample, Vector2(60, 36)), sample)


static func _px(x: float, y: float) -> Vector2:
	return ANCHOR + Vector2(x, y) * U


static func _hip(k: int) -> Vector2:
	return _px(-6.0 + float(k) * 6.0, -11.7 * 0.62)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", -1.0)
	var r: float = ViewUtil.gf(f, "r", 12.0)
	var s: float = r / 12.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var bite: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var bob: float = absf(sin(walk * 0.5)) * 1.1 if grounded else 0.0
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r - 4.0 if drowning else 0.0))
	var root := Transform2D(ViewUtil.gf(f, "flip_angle"), Vector2(facing * s, s), 0.0, origin)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning)
	var ground: float = r / s - 0.3
	for i in 6:
		var near: bool = i < 3
		var k: int = i % 3
		var ph: float = walk + float(k) * 2.1 + (0.0 if near else PI)
		var sw: float = sin(ph) * 5.5 if grounded else 2.0
		var lift: float = maxf(0.0, cos(ph)) * 3.0 if grounded else 4.0
		rig.set_pose("leg%d_%s" % [k, "near" if near else "far"], -sw / (ground + ground * 0.62), Vector2(0.0, -lift * U))
	var up := Vector2(0.0, -bob * U)
	for p in BODY:
		rig.set_pose(p, 0.0, up)
	var open: float = sin(bite * PI) * 3.2
	rig.set_pose("mandible_down", open * 0.2, up)
	rig.set_pose("mandible_up", -open * 0.08, up)
	var wig: float = sin(t * 8.0 + float(ViewUtil.gi(f, "id"))) * 1.4
	rig.set_pose("antenna_a", wig * 0.07, up)
	rig.set_pose("antenna_b", wig * 0.07, up)
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var by: float = -ground * 0.78 - bob
	var head := Vector2(14.6, by + 0.2)
	ci.draw_circle(head + Vector2(1.0, -1.2), 1.5, Color("#f6e7a8"))
	ci.draw_circle(head + Vector2(1.4, -1.2), 0.75, Color("#a8261c") if bite > 0.0 else Color("#10201a"))
	hurt_flash(ci, Vector2(0.0, by), 15.0, 8.0, hurt)
	water_wash(ci, Vector2(0.0, by), 16.0, 9.0, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
