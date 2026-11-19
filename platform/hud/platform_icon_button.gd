## Round button with a pause icon (two bars). Works with mouse and touch.
class_name PlatformIconButton
extends Control

signal pressed

var _down: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(56.0, 56.0)
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_down = true
		elif _down:
			_down = false
			pressed.emit()
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, Color(0.06, 0.07, 0.1, 0.62 if not _down else 0.85))
	draw_arc(c, r, 0.0, TAU, 32, Color(0.96, 0.81, 0.47, 0.7), 2.0, true)
	var w: float = r * 0.2
	var h: float = r * 0.8
	draw_rect(Rect2(c.x - w * 1.6, c.y - h * 0.5, w, h), Palette.IVORY)
	draw_rect(Rect2(c.x + w * 0.6, c.y - h * 0.5, w, h), Palette.IVORY)
