## CutoutRig with the helpers the boss arts share: an anchor held by the rig, hiding a part (scale ~ 0), moving a part's pivot to a
## viewBox point, converting viewBox points to rig space and drawing with a modulate colour (translucent wing ghosts).
class_name BossRig
extends CutoutRig

const HIDDEN := Vector2(0.001, 0.001)

## Point of the 128-unit viewBox that lands on the rig origin.
var anchor: Vector2 = Vector2(64.0, 64.0)


func _init(p_group: String, p_id: String, p_box: float, p_anchor: Vector2 = Vector2(64.0, 64.0)) -> void:
	super(p_group, p_id, p_box)
	anchor = p_anchor


## World-px scale of one viewBox unit.
func k() -> float:
	return box / SpriteArt.VIEWBOX


## ViewBox point -> rig space (px).
func pt(vb: Vector2) -> Vector2:
	return (vb - anchor) * k()


func hide(part: String) -> void:
	set_pose(part, 0.0, Vector2.ZERO, HIDDEN)


## Rotates `part` by `rot` around its pivot, with the pivot moved to the viewBox point `target`.
func pose_at(part: String, target: Vector2, rot: float, part_scale: Vector2 = Vector2.ONE) -> void:
	set_pose(part, rot, target - (_pivot[part] as Vector2), part_scale)


## Draws the parts in `only` (all when empty) with `mod` multiplied in.
func draw_mod(ci: CanvasItem, root: Transform2D, mod: Color = Color.WHITE, only: Array = []) -> void:
	var kk: float = k()
	for part in _names:
		if not only.is_empty() and not only.has(part):
			continue
		var tex: Texture2D = part_texture(part)
		if tex == null:
			continue
		var pivot: Vector2 = _pivot[part]
		var pose: Array = _pose[part]
		var local := Transform2D(0.0, Vector2.ONE, 0.0, (pivot - anchor + (_rest[part] as Vector2)) * kk) * Transform2D(float(pose[0]), pose[2] as Vector2, 0.0, (pose[1] as Vector2) * kk)
		ci.draw_set_transform_matrix(root * local)
		ci.draw_texture_rect(tex, Rect2(-pivot * kk, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * kk), false, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
