## Animated phone drawing of the rotate-device card (SVG shapes of index.html, tilt keyframes of `tiltToLandscape`, 2.2 s loop).
class_name RotatePhoneIcon
extends Control

const PERIOD := 2.2
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(80, 80)
	pivot_offset = Vector2(40, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t = fposmod(_t + delta, PERIOD)
	var k: float = _t / PERIOD
	var angle: float = 0.0
	if k < 0.15:
		angle = 0.0
	elif k < 0.55:
		angle = -90.0 * smoothstep(0.15, 0.55, k)
	elif k < 0.80:
		angle = -90.0
	else:
		angle = -90.0 * (1.0 - smoothstep(0.80, 1.0, k))
	rotation_degrees = angle


func _draw() -> void:
	var body := Rect2(22, 10, 36, 60)
	draw_rect(body, Color(20.0 / 255.0, 24.0 / 255.0, 32.0 / 255.0, 0.9))
	draw_rect(body, Palette.BRASS_BRIGHT, false, 3.0)
	draw_line(Vector2(35, 15), Vector2(45, 15), Palette.BRASS, 2.0)
	draw_circle(Vector2(40, 63), 2.5, Palette.BRASS_BRIGHT)
	var arc := PackedVector2Array()
	for i in 13:
		var u: float = float(i) / 12.0
		var a := Vector2(12, 44)
		var c1 := Vector2(10, 28)
		var c2 := Vector2(20, 16)
		var b := Vector2(32, 14)
		arc.append(a.bezier_interpolate(c1, c2, b, u))
	for i in range(0, arc.size() - 1, 2):
		draw_line(arc[i], arc[i + 1], Palette.TEAM_GOLD, 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(32, 10), Vector2(38, 14), Vector2(31, 18)]), Palette.TEAM_GOLD)
