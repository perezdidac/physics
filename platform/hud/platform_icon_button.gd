## Chamfered square button with a pause icon (two bars). Works with mouse and touch.
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
	var rect := Rect2(Vector2.ZERO, size)
	var cut: float = clampf(minf(size.x, size.y) * 0.16, 5.0, 8.0)
	var top := Color(0.105, 0.125, 0.17, 0.96)
	var bottom := Color(0.05, 0.062, 0.088, 0.98)
	if _down:
		top = Color(0.35, 0.25, 0.1, 0.98)
		bottom = Color(0.2, 0.14, 0.05, 0.98)
	ChamferShape.draw(self, rect, Vector4(0, cut, 0, cut), top, bottom, Palette.BRASS_BRIGHT if _down else Palette.BRASS, 1.5)
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	var w: float = r * 0.22
	var h: float = r * 0.9
	draw_rect(Rect2(c.x - w * 1.6, c.y - h * 0.5, w, h), Palette.IVORY)
	draw_rect(Rect2(c.x + w * 0.6, c.y - h * 0.5, w, h), Palette.IVORY)
