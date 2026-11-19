## The small health bar of El Bolsó (the nest) shown under the objective: a silk-white fill that turns orange and then red as the nest wears
## down, with a lighter trail that catches up after a hit and the numbers on top. Pure drawing; TopHud feeds it.
class_name NestBar
extends Control

var fraction: float = 1.0
var hp_text: String = ""
var _trail: float = 1.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_trail = maxf(fraction, _trail - delta * 0.35) if _trail > fraction else fraction
	if visible:
		queue_redraw()


## The fill colour for a nest fraction: silk white, then orange, then red.
static func fill_color(frac: float) -> Color:
	if frac > 0.55:
		return Color("#e8eef5")
	return Color("#ffb347").lerp(Color("#ff5a4a"), clampf(1.0 - frac / 0.55, 0.0, 1.0)) if frac > 0.0 else Color("#ff5a4a")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var rr: float = size.y * 0.5
	ViewUtil.fill_round_rect(self, rect.grow(1.2), rr + 1.2, Palette.BRASS_DIM)
	ViewUtil.fill_round_rect(self, rect, rr, Color(0.04, 0.05, 0.08, 0.92))
	var inner: Rect2 = rect.grow(-1.5)
	if _trail > fraction:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), inner.size.y * 0.5, Color(1.0, 0.86, 0.72, 0.8))
	if fraction > 0.0:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * fraction), inner.size.y)), inner.size.y * 0.5, fill_color(fraction))
	if hp_text != "" and size.y >= 9.0:
		var fs: int = roundi(size.y * 0.7)
		ViewUtil.text(self, hp_text, Vector2(size.x * 0.5 + 1.0, size.y * 0.5 + fs * 0.36 + 1.0), fs, Color(0.0, 0.0, 0.0, 0.6))
		ViewUtil.text(self, hp_text, Vector2(size.x * 0.5, size.y * 0.5 + fs * 0.36), fs, Palette.INK_ON_BRASS if fraction > 0.55 else Palette.IVORY)
