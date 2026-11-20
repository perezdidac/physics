## Row of three five-point stars (filled up to `count`), drawn with polygons so no font glyph is needed.
class_name StarRow
extends Control

## Stars shown filled (0-3).
var count: int = 0:
	set(value):
		count = value
		queue_redraw()
var star_size: float = 16.0:
	set(value):
		star_size = value
		custom_minimum_size = Vector2(star_size * 3.2, star_size)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(star_size * 3.2, star_size)


func _draw() -> void:
	var r: float = star_size * 0.5
	for i in 3:
		var c := Vector2(star_size * 0.5 + i * star_size * 1.1, star_size * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var ang: float = -PI / 2.0 + k * PI / 5.0
			var rad: float = r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		var filled: bool = i < count
		draw_colored_polygon(pts, Palette.BRASS_BRIGHT if filled else Palette.IVORY_FAINT)
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Palette.BRASS if filled else Palette.IVORY_FAINT, 1.0, true)
