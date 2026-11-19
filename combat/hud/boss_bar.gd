## The big boss health bar: a red fill with a lighter trail that catches up after a hit, a tick where each phase starts, and one pip per
## phase at the right end (filled up to the current phase). Pure drawing; BossHud feeds it.
class_name BossBar
extends Control

var fraction: float = 1.0
## HP fractions where the phase changes (BossDef.phases).
var phase_marks: Array[float] = []
## Current phase, counting from 1.
var phase: int = 1
## True while the boss takes full damage: the fill glows gold.
var vulnerable: bool = false
var hp_text: String = ""
var _trail: float = 1.0
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if _trail > fraction:
		_trail = maxf(fraction, _trail - delta * 0.35)
	else:
		_trail = fraction
	queue_redraw()


func _draw() -> void:
	var pip_r: float = minf(5.0, size.y * 0.38)
	var pips_w: float = (phase_marks.size() + 1) * (pip_r * 2.0 + 4.0) if not phase_marks.is_empty() else 0.0
	var bar := Rect2(0.0, 0.0, size.x - pips_w - (6.0 if pips_w > 0.0 else 0.0), size.y)
	var round_r: float = bar.size.y * 0.45
	ViewUtil.fill_round_rect(self, bar.grow(1.5), round_r + 1.5, Palette.BRASS_DIM)
	ViewUtil.fill_round_rect(self, bar, round_r, Color(0.04, 0.05, 0.08, 0.92))
	var inner: Rect2 = bar.grow(-2.0)
	if _trail > fraction:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), inner.size.y * 0.45, Color(1.0, 0.86, 0.72, 0.85))
	var fill_col: Color = Palette.TEAM_CRIMSON.lerp(Palette.BRASS_BRIGHT, 0.55 + 0.45 * sin(_t * 7.0)) if vulnerable else Palette.TEAM_CRIMSON
	if fraction > 0.0:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * fraction), inner.size.y)), inner.size.y * 0.45, fill_col)
		ViewUtil.fill_round_rect(self, Rect2(inner.position + Vector2(2.0, 1.0), Vector2(maxf(2.0, inner.size.x * fraction - 4.0), inner.size.y * 0.35)), inner.size.y * 0.18, Color(1, 1, 1, 0.2))
	for m in phase_marks:
		var x: float = inner.position.x + inner.size.x * m
		draw_line(Vector2(x, bar.position.y + 1.0), Vector2(x, bar.end.y - 1.0), Palette.IVORY, 2.0)
	if hp_text != "" and size.y >= 16.0:
		var font: Font = ThemeDB.fallback_font
		var fs: int = roundi(size.y * 0.62)
		var w: float = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(bar.size.x * 0.5 - w * 0.5 + 1.0, size.y * 0.5 + fs * 0.36 + 1.0), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(bar.size.x * 0.5 - w * 0.5, size.y * 0.5 + fs * 0.36), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.IVORY)
	for i in phase_marks.size() + 1:
		var c := Vector2(bar.end.x + 6.0 + pip_r + float(i) * (pip_r * 2.0 + 4.0), size.y * 0.5)
		draw_circle(c, pip_r + 1.2, Palette.BRASS_DIM)
		draw_circle(c, pip_r, Palette.BRASS_BRIGHT if i < phase else Color(0.04, 0.05, 0.08, 0.92))
