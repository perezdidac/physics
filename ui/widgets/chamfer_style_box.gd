## StyleBox that draws the chamfered (cut corners) gradient shape of ChamferButton, so plain Buttons of the theme
## (CmdButton, CmdIconButton) share the look of the gold deploy button.
class_name ChamferStyleBox
extends StyleBox

@export var cuts: Vector4 = Vector4(0, 8, 0, 8)
@export var top: Color = Color.TRANSPARENT
@export var bottom: Color = Color.TRANSPARENT
@export var border: Color = Color.TRANSPARENT
@export var border_width: float = 1.5
## Extra ring drawn around the shape (keyboard focus). Zero width disables it.
@export var ring: bool = false


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var inner: Rect2 = rect.grow(-border_width * 0.5)
	var pts: PackedVector2Array = ChamferShape.points(inner, cuts)
	if not ring:
		var colors := PackedColorArray()
		for p in pts:
			var k: float = clampf((p.y - inner.position.y) / maxf(inner.size.y, 1.0), 0.0, 1.0)
			colors.append(top.lerp(bottom, k))
		if top.a > 0.0 or bottom.a > 0.0:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, colors)
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	if ring:
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([Palette.FOCUS_RING]), 6.0, true)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([Palette.FOCUS_OUTLINE]), 2.5, true)
	elif border_width > 0.0 and border.a > 0.0:
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([border]), border_width, true)
