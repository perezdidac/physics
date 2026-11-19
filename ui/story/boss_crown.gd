## Small crown-and-stinger badge drawn with polygons: marks the boss node of a stage on the story map.
class_name BossCrown
extends Control

var icon_size: float = 22.0:
	set(value):
		icon_size = value
		custom_minimum_size = Vector2(icon_size * 1.2, icon_size)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(icon_size * 1.2, icon_size)


func _draw() -> void:
	var w: float = icon_size * 1.2
	var h: float = icon_size
	var base_y: float = h * 0.9
	var crown := PackedVector2Array([
		Vector2(w * 0.08, base_y), Vector2(w * 0.04, h * 0.2), Vector2(w * 0.28, h * 0.5), Vector2(w * 0.5, h * 0.06),
		Vector2(w * 0.72, h * 0.5), Vector2(w * 0.96, h * 0.2), Vector2(w * 0.92, base_y),
	])
	draw_colored_polygon(crown, Palette.BRASS_BRIGHT)
	var loop: PackedVector2Array = crown.duplicate()
	loop.append(crown[0])
	draw_polyline(loop, Palette.TITLE_BOTTOM, 1.2, true)
	draw_rect(Rect2(w * 0.08, base_y - h * 0.16, w * 0.84, h * 0.16), Palette.TITLE_BOTTOM)
	for k in 3:
		draw_circle(Vector2(w * (0.3 + 0.2 * float(k)), base_y - h * 0.08), h * 0.06, Palette.FT_WINE)
