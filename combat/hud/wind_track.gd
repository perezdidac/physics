## Anemometer bar (.wind-track): 82x5 track, centre tick, bar growing left (blue) or right (gold) from the centre.
class_name WindTrack
extends Control

## Wind in -max_wind..max_wind (the sim's integer `wind`; story levels scale it up to 1.8x).
var wind: float = 0.0:
	set(value):
		if wind != value:
			wind = value
			queue_redraw()
## Wind at which the bar is full (100 in classic matches).
var max_wind: float = 100.0
var gust_flash: bool = false:
	set(value):
		if gust_flash != value:
			gust_flash = value
			queue_redraw()
var _shown: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(82, 5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_equal_approx(_shown, wind):
		_shown = lerpf(_shown, wind, clampf(delta * 12.0, 0.0, 1.0))
		if absf(_shown - wind) < 0.2:
			_shown = wind
		queue_redraw()


func _draw() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.WIND_TRACK_BG
	track.border_color = Palette.WIND_TRACK_BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var half: float = size.x * 0.5
	var w: float = clampf(absf(_shown) / maxf(1.0, max_wind) * 50.0, 0.0, 50.0) / 100.0 * size.x
	if w >= 0.5:
		var col: Color
		if _shown >= 0.0:
			col = Palette.WIND_GUST_RIGHT if gust_flash else Palette.WIND_RIGHT
			draw_rect(Rect2(half, 1, w, size.y - 2), col)
		else:
			col = Palette.WIND_GUST_LEFT if gust_flash else Palette.WIND_LEFT
			draw_rect(Rect2(half - w, 1, w, size.y - 2), col)
	draw_line(Vector2(half, 0), Vector2(half, size.y), Palette.BRASS, 1.0)
