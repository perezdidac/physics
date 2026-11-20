## Bar at the top centre of a boss level: the text "Hatching in N s" over a bar that fills up as the egg nears the hatching.
class_name PlatformBossBar
extends Control

var compact: bool = false
var text: String = ""
var fraction: float = 0.0
var seconds_left: float = 0.0
## What rides the bar: "egg" (wasp level), "pupa" (hoopoe) or "moth" (bat).
var rider: String = "egg"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor_left = 0.5
	anchor_right = 0.5


## Sets the remaining time; `format` is the translated "Hatching in %d s".
func set_time(time_left: float, total: float, format: String) -> void:
	seconds_left = maxf(time_left, 0.0)
	fraction = 1.0 - clampf(time_left / maxf(total, 0.01), 0.0, 1.0)
	var n: int = int(ceilf(seconds_left))
	text = format % n if format.contains("%") else "%s %d" % [format, n]
	var w: float = 230.0 if compact else 320.0
	custom_minimum_size = Vector2(w, 44.0 if compact else 54.0)
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = 10.0
	offset_bottom = 10.0 + custom_minimum_size.y
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var fs: int = 14 if compact else 18
	var bar := Rect2(4.0, size.y - (14.0 if compact else 18.0), w - 8.0, 10.0 if compact else 12.0)
	var urgent: bool = seconds_left <= 10.0
	var col: Color = Palette.LOW_TIME_RED if urgent and int(Time.get_ticks_msec() * 0.004) % 2 == 0 else Palette.BRASS_BRIGHT
	var pill_w: float = ViewUtil.text_w(text, fs) + 24.0
	ViewUtil.fill_round_rect(self, Rect2((w - pill_w) * 0.5, size.y - bar.size.y - 9.0 - float(fs) - 2.0, pill_w, float(fs) + 10.0), 9.0, Color(0.05, 0.04, 0.03, 0.55))
	ViewUtil.text(self, text, Vector2(w * 0.5 + 1.0, size.y - bar.size.y - 9.0 + 2.0), fs, Color(0, 0, 0, 0.6))
	ViewUtil.text(self, text, Vector2(w * 0.5, size.y - bar.size.y - 9.0), fs, col)
	ViewUtil.fill_round_rect(self, bar.grow(2.0), 7.0, Color(0.05, 0.04, 0.03, 0.75))
	ViewUtil.fill_round_rect(self, Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), 5.0, Palette.TEAM_GOLD)
	ViewUtil.fill_round_rect(self, Rect2(bar.position + Vector2(2.0, 1.0), Vector2(maxf(bar.size.x * fraction - 4.0, 0.0), 3.0)), 2.0, Color(1.0, 1.0, 0.85, 0.5))
	ViewUtil.stroke_round_rect(self, bar.grow(2.0), 7.0, Palette.BRASS, 1.2)
	# a little egg, pupa or moth riding the bar
	var rc := Vector2(bar.position.x + bar.size.x * fraction, bar.position.y + bar.size.y * 0.5)
	match rider:
		"pupa":
			ViewUtil.fill_ellipse(self, rc, 5.0, 8.5, ViewColors.h("#8a5a34"))
			ViewUtil.stroke_ellipse(self, rc, 5.0, 8.5, Palette.BRASS, 1.2)
			draw_line(rc + Vector2(-4.0, 1.5), rc + Vector2(4.0, 1.5), Color(0.3, 0.17, 0.08, 0.8), 1.0)
		"moth":
			for side: float in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([rc, rc + Vector2(side * 11.0, -8.0), rc + Vector2(side * 9.0, 3.0)]), ViewColors.h("#d6cfc0"))
			ViewUtil.fill_ellipse(self, rc, 2.6, 6.0, ViewColors.h("#7d6a52"))
		_:
			ViewUtil.fill_ellipse(self, rc, 6.0, 7.5, Color(0.98, 0.96, 0.88, 1.0))
			ViewUtil.stroke_ellipse(self, rc, 6.0, 7.5, Palette.BRASS, 1.2)
