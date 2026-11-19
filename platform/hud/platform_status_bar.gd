## Top-left status of the platformer: hearts and the sap-drop counter N/M.
class_name PlatformStatusBar
extends Control

var hearts: int = 3
var max_hearts: int = 3
var nutrients: int = 0
var nutrients_total: int = 0
## Seconds left of the flash after losing a heart.
var _flash: float = 0.0
var heart_size: float = 30.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Updates the numbers; a lost heart flashes.
func set_state(p_hearts: int, p_max: int, p_nutrients: int, p_total: int) -> void:
	if p_hearts < hearts:
		_flash = 0.6
	if p_hearts != hearts or p_max != max_hearts or p_nutrients != nutrients or p_total != nutrients_total:
		queue_redraw()
	hearts = p_hearts
	max_hearts = p_max
	nutrients = p_nutrients
	nutrients_total = p_total


## "3/12".
func nutrient_text() -> String:
	return "%d/%d" % [nutrients, nutrients_total]


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(heart_size * 1.25 * float(maxi(max_hearts, 3)) + 130.0, heart_size * 1.9)


func _draw() -> void:
	var s: float = heart_size
	for i in max_hearts:
		var c := Vector2(s * 0.62 + float(i) * s * 1.25, s * 0.6)
		var full: bool = i < hearts
		var pop: float = 1.0 + (0.25 * sin(_flash * 20.0) if _flash > 0.0 and i == hearts else 0.0)
		_heart(c, s * 0.5 * pop, full)
	if nutrients_total == 0:
		return
	var y: float = s * 1.55
	var x: float = s * 0.62
	_drop(Vector2(x, y), s * 0.34)
	ViewUtil.text(self, nutrient_text(), Vector2(x + s * 0.55, y + s * 0.3), int(s * 0.85), Palette.IVORY, false)


func _heart(c: Vector2, r: float, full: bool) -> void:
	var fill: Color = Color("#e8404f") if full else Color(0.1, 0.1, 0.12, 0.55)
	var line: Color = Color("#4a0f18") if full else Color(0.85, 0.8, 0.7, 0.45)
	var pts := PackedVector2Array()
	for k in 25:
		var t: float = float(k) / 24.0 * TAU
		var px: float = 16.0 * pow(sin(t), 3.0)
		var py: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(px, py) * (r / 16.0))
	draw_colored_polygon(pts, fill)
	draw_polyline(pts, line, 2.0, true)
	if full:
		ViewUtil.fill_ellipse(self, c + Vector2(-r * 0.4, -r * 0.35), r * 0.2, r * 0.3, Color(1, 1, 1, 0.55), 0.6)


func _drop(c: Vector2, r: float) -> void:
	for k in 3:
		draw_circle(c, r * (2.0 - float(k) * 0.4), Color(1.0, 0.72, 0.2, 0.1 + float(k) * 0.05))
	var pts := PackedVector2Array()
	for k in 21:
		var a: float = float(k) / 20.0 * TAU
		var px: float = sin(a) * r
		var py: float = -cos(a) * r
		if py < 0.0:
			px *= 1.0 - (-py / r) * 0.85
			py *= 1.7
		pts.append(c + Vector2(px, py + r * 0.3))
	draw_colored_polygon(pts, Color("#ffb938"))
	draw_polyline(pts, Color("#b8680f"), 1.5, true)
