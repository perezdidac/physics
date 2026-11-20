## Container with a chamfered, gradient-filled background (lobby frame, squad boxes, victory and rotate cards).
class_name ChamferPanel
extends PanelContainer

@export var cuts: Vector4 = Vector4(0, 0, 0, 0)
@export var fill_top: Color = Palette.FRAME_TOP
@export var fill_bottom: Color = Palette.FRAME_BOTTOM
@export var border_color: Color = Palette.BRASS
@export var border_width: float = 1.0
## Inner padding in pixels (left, top, right, bottom).
@export var padding: Vector4 = Vector4(12, 12, 12, 12)


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = padding.x
	empty.content_margin_top = padding.y
	empty.content_margin_right = padding.z
	empty.content_margin_bottom = padding.w
	add_theme_stylebox_override("panel", empty)


func _draw() -> void:
	ChamferShape.draw(self, Rect2(Vector2.ZERO, size), cuts, fill_top, fill_bottom, border_color, border_width)
