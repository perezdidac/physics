## Round, semi-transparent on-screen button for the touch controls. Reports press and release separately and works with
## several fingers at once. `fill` (0..1) draws a charge ring around it (the FIRE button).
class_name TouchButton
extends Control

signal pressed_down
signal released
## Emitted on release when the finger is still over the button.
signal tapped

enum Style { NORMAL, FIRE }

var style: Style = Style.NORMAL
var text: String = "":
	set(value):
		text = value
		queue_redraw()
## Small second line (the ammo of the weapon button).
var sub_text: String = "":
	set(value):
		sub_text = value
		queue_redraw()
var icon: Texture2D = null:
	set(value):
		icon = value
		queue_redraw()
var fill: float = 0.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()
var is_down: bool = false
var _touch_index: int = -1


func _init(button_style: Style = Style.NORMAL, label_text: String = "") -> void:
	style = button_style
	text = label_text
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets the diameter.
func set_diameter(d: float) -> void:
	custom_minimum_size = Vector2(d, d)
	size = Vector2(d, d)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin(-1)
			else:
				_end(-1, _has_point(mb.position))
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin(st.index)
		else:
			_end(st.index, _has_point(st.position))
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
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var fire: bool = style == Style.FIRE
	var base: Color = Palette.FIRE_BOTTOM if fire else Palette.BTN_BOTTOM
	var lit: Color = Palette.FIRE_MID if fire else Palette.BTN_TOP_SELECTED
	draw_circle(c, r, Color(lit if is_down else base, 0.62 if fire else 0.58))
	draw_arc(c, r, 0.0, TAU, 48, Color(Palette.FOCUS_BORDER if fire else Palette.BRASS_BRIGHT, 0.55 if is_down else 0.4), 2.5, true)
	if fill > 0.0:
		draw_arc(c, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Palette.FIRE_TOP, maxf(5.0, r * 0.1), true)
	var font: Font = get_theme_font("font", "TitleBlackLabel" if fire else "BodyBoldLabel")
	var fs: int = int(clampf(r * (0.3 if fire else 0.34), 12.0, 40.0))
	var col: Color = Color.WHITE if (fire or is_down) else Palette.IVORY
	if icon != null:
		var tsz: Vector2 = icon.get_size()
		var k: float = minf(r * 1.2 / tsz.x, r * 0.8 / tsz.y)
		var isz: Vector2 = tsz * k
		draw_texture_rect(icon, Rect2(c.x - isz.x * 0.5, c.y - isz.y * 0.5 - r * 0.2, isz.x, isz.y), false)
		if not sub_text.is_empty():
			draw_string(font, Vector2(0, c.y + r * 0.62), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(fs * 0.8), Palette.BRASS_BRIGHT)
		return
	while fs > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x * 0.82:
		fs -= 1
	var y: float = c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)
