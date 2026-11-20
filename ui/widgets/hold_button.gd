## Touch/mouse button that reports press and release separately and supports several fingers at once
## (the original gamepad buttons, main.js bindHoldButton). Drawn like `.mc-btn` / `.mc-btn-fire`.
class_name HoldButton
extends Control

signal pressed_down
signal released
## Emitted on release when the pointer is still over the button (a tap).
signal tapped

enum Kind { NORMAL, ARROW, UTIL, FIRE }

var text: String = "":
	set(value):
		text = value
		queue_redraw()
var kind: Kind = Kind.NORMAL
## Fire button only: charge bar 0..1 drawn as a translucent white fill from the left.
var fill: float = 0.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()
var is_down: bool = false
var _touch_index: int = -1


func _init(button_kind: Kind = Kind.NORMAL, label_text: String = "") -> void:
	kind = button_kind
	text = label_text
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = _min_size(false)


## Re-applies the compact (phone landscape) sizes.
func set_compact(compact: bool) -> void:
	custom_minimum_size = _min_size(compact)


func _min_size(compact: bool) -> Vector2:
	match kind:
		Kind.ARROW:
			return Vector2(40, 38) if compact else Vector2(48, 44)
		Kind.UTIL:
			return Vector2(32, 34) if compact else Vector2(36, 36)
		Kind.FIRE:
			return Vector2(88, 40) if compact else Vector2(108, 50)
	return Vector2(38, 36) if compact else Vector2(46, 44)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin(-1)
			else:
				_end(-1, Rect2(Vector2.ZERO, size).has_point(mb.position))
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin(st.index)
		else:
			_end(st.index, Rect2(Vector2.ZERO, size).has_point(st.position))
		accept_event()


func _begin(index: int) -> void:
	if is_down:
		return
	is_down = true
	_touch_index = index
	queue_redraw()
	pressed_down.emit()


func _end(index: int, inside: bool) -> void:
	if not is_down:
		return
	if index != _touch_index and index != -1 and _touch_index != -1:
		return
	is_down = false
	_touch_index = -1
	queue_redraw()
	released.emit()
	if inside:
		tapped.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and is_down:
		is_down = false
		_touch_index = -1
		released.emit()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var font_name: String = "BodyBoldLabel" if kind == Kind.ARROW else "CmdButton"
	var font: Font = UiUtil.get_theme().get_font("font", font_name)
	var label: String = text if kind == Kind.ARROW or kind == Kind.FIRE else text.to_upper()
	var font_size: int = 12
	match kind:
		Kind.ARROW:
			font_size = 17
		Kind.UTIL:
			font_size = 11
		Kind.FIRE:
			font_size = 14
	# Big touch buttons (TouchMetrics) get a bigger label, kept inside the button width.
	font_size = int(round(font_size * clampf(size.y / 44.0, 1.0, 2.2)))
	while font_size > 9 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x * 0.88:
		font_size -= 1
	var col: Color = Palette.IVORY
	if kind == Kind.FIRE:
		var top: Color = Palette.FIRE_TOP
		var bottom: Color = Palette.FIRE_BOTTOM
		if is_down:
			top = top.lightened(0.15)
			bottom = bottom.lightened(0.15)
		ChamferShape.draw(self, rect, Vector4.ZERO, top, bottom, Palette.FOCUS_BORDER, 2.0)
		if fill > 0.0:
			draw_rect(Rect2(2, 2, (size.x - 4.0) * fill, size.y - 4.0), Color(1, 1, 1, 0.28))
		col = Color.WHITE
	elif kind != Kind.ARROW:
		# Secondary family: chamfered, dark fill, brass border (same as CmdButton).
		var cut: float = clampf(size.y * 0.16, 5.0, 9.0)
		var ctop := Color(0.105, 0.125, 0.17, 0.96)
		var cbottom := Color(0.05, 0.062, 0.088, 0.98)
		var cborder: Color = Palette.BRASS
		if is_down:
			ctop = Color(0.35, 0.25, 0.1, 0.98)
			cbottom = Color(0.2, 0.14, 0.05, 0.98)
			cborder = Palette.BRASS_BRIGHT
			col = Palette.BRASS_BRIGHT
		ChamferShape.draw(self, rect, Vector4(0, cut, 0, cut), ctop, cbottom, cborder, 1.5)
	else:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(7 if kind == Kind.UTIL else 8)
		sb.set_border_width_all(2)
		sb.anti_aliasing = true
		if is_down:
			sb.bg_color = Color(120.0 / 255.0, 86.0 / 255.0, 30.0 / 255.0, 0.96)
			sb.border_color = Palette.BRASS_BRIGHT
			col = Palette.BRASS_BRIGHT
		else:
			sb.bg_color = Color(18.0 / 255.0, 23.0 / 255.0, 32.0 / 255.0, 0.95)
			sb.border_color = Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.52)
		draw_style_box(sb, rect)
	var pos_y: float = (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(0, pos_y), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, col)
