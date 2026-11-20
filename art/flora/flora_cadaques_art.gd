## Surface plant of the "CADAQUES" maps.
class_name FloraCadaquesArt
extends FloraArt


func _draw_plant(ci: CanvasItem, fl: Variant, variant: int, sway: float, sc: float) -> void:
	if _draw_sprite(ci, "cadaques", variant, 2):
		return
	if variant == 0:
		for b in range(-2, 3):
			ArtKit.place(ci, ViewUtil.pos(fl), sway + float(b) * 0.36, Vector2(sc, sc))
			var leaf := PackedVector2Array()
			leaf.append_array(ViewUtil.quad_pts(Vector2(-2, 1), Vector2(0, -13), Vector2(0, -15), 6))
			leaf.append_array(ViewUtil.quad_pts(Vector2(0, -15), Vector2(0, -13), Vector2(2, 1), 6))
			ArtKit.poly(ci, leaf, ViewColors.h("#4e7a6b"), ViewColors.h("#254238"), 1.1)
	else:
		var pear := ViewColors.h("#5c8c46")
		var edge := ViewColors.h("#2b471f")
		ViewUtil.ellipse_fs(ci, Vector2(0, -5), 4.5, 5.5, pear, edge, 1.1)
		ViewUtil.ellipse_fs(ci, Vector2(-4.5, -11), 3.2, 4.2, pear, edge, 1.1, -0.35)
		ViewUtil.ellipse_fs(ci, Vector2(4.2, -10), 3.0, 3.8, pear, edge, 1.1, 0.35)
		ci.draw_circle(Vector2(-6, -15), 1.7, ViewColors.h("#ff7043"))
		ci.draw_circle(Vector2(5.5, -13.5), 1.6, ViewColors.h("#ff7043"))
