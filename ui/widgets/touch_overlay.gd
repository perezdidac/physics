## Visual feedback of the touch controls: the aim-drag line and the hint of the current phase. Draws only, never takes input.
## Fed by CombatInput through `show_aim` and `hide_aim` (see `bind_input`).
class_name TouchOverlay
extends Control

var aim_visible: bool = false
var aim_from: Vector2 = Vector2.ZERO
var aim_to: Vector2 = Vector2.ZERO
var aim_degrees: float = 0.0
## Small hint of the current touch phase (already translated, empty = none), set by BottomHud.
var phase_text: String = "":
	set(value):
		if value != phase_text:
			phase_text = value
			queue_redraw()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Connects to a CombatInput (anything with the aim_drag_changed signal).
func bind_input(input: Object) -> void:
	if input == null:
		return
	if not input.is_connected("aim_drag_changed", _on_aim):
		input.connect("aim_drag_changed", _on_aim)


func _on_aim(active: bool, from: Vector2, to: Vector2, degrees: float) -> void:
	if active:
		show_aim(from, to, degrees)
	else:
		hide_aim()


func show_aim(from: Vector2, to: Vector2, degrees: float) -> void:
	aim_visible = true
	aim_from = from
	aim_to = to
	aim_degrees = degrees
	queue_redraw()


func hide_aim() -> void:
	aim_visible = false
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if not phase_text.is_empty() and TouchMetrics.active(vp):
		var font_h: Font = get_theme_font("font", "BodyBoldLabel")
		var fs: int = 16
		var sz: Vector2 = font_h.get_string_size(phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var box := Rect2(Vector2((vp.x - sz.x) * 0.5 - 12.0, vp.y * 0.34), sz + Vector2(24.0, 12.0))
		draw_rect(box, Color(Palette.BTN_BOTTOM, 0.6))
		draw_string(font_h, box.position + Vector2(12.0, sz.y + 1.0), phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.IVORY)
	if aim_visible:
		draw_dashed_line(aim_from, aim_to, Color(Palette.FOCUS_BORDER, 0.85), 3.0, 10.0)
		draw_circle(aim_to, 16.0, Color(Palette.BRASS_BRIGHT, 0.45))
		draw_arc(aim_to, 16.0, 0.0, TAU, 24, Palette.FOCUS_BORDER, 2.5, true)
		var font: Font = get_theme_font("font", "MonoHeavyLabel")
		draw_string(font, aim_to + Vector2(-30, -26), "%d°" % int(round(aim_degrees)), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 18, Palette.IVORY)
