## Perleta, the egg fighter, as a sprite (assets/sprites/creatures/egg/body.svg, pivot at the ground contact) that rocks and squashes
## with the crawl like EggArt. The face (blink, hurt crosses, cheek, smile), the red hit flash and the hidden alpha are code.
class_name EggSpriteArt
extends CritterSpriteArt

const BOX: float = 32.0
const ANCHOR := Vector2(64.0, 110.0)


func _init() -> void:
	var r := CreatureRig.new("egg", BOX)
	r.add_part("body", ANCHOR)
	var sample := {"x": 0.0, "y": -10.5, "r": 11.0, "walk_cycle": 0.0, "facing": 1.0, "grounded": true, "id": 0}
	super(r, CritterVectorArt.new("egg", sample, Vector2(30, 36)), sample)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var a: float = ViewUtil.gf(f, "alpha", -1.0)
	if a < 0.0:
		a = 0.45 if ViewUtil.gb(f, "hidden") else 1.0
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 10.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var moving: float = clampf(absf(ViewUtil.gf(f, "vx")) * 0.04, 0.0, 1.0) if not ViewUtil.gb(f, "grounded", true) else 1.0
	var rock: float = sin(walk * 0.9) * 0.13 * moving
	var squash: float = sin(walk * 1.8) * 0.05 * moving
	var breathe: float = sin(t * 2.2 + ViewUtil.gf(f, "x") * 0.1) * 0.012
	var sx: float = ViewUtil.gf(f, "squash_x", 1.0) * (1.0 - squash + breathe)
	var sy: float = ViewUtil.gf(f, "squash_y", 1.0) * (1.0 + squash - breathe)
	var feet := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + r - 0.5 - (4.0 if drowning else 0.0))
	var root := Transform2D(rock, Vector2(sx, sy), 0.0, feet)
	rig.reset_poses()
	rig.modulate = drown_tint(drowning) * Color(1, 1, 1, a)
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	var c := Vector2(0.0, -EggArt.RY + 0.5)
	EggArt._draw_face(ci, f, c, facing, t, hurt, a)
	hurt_flash(ci, c, EggArt.RX, EggArt.RY, hurt * a)
	water_wash(ci, c, EggArt.RX, EggArt.RY, drowning)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
