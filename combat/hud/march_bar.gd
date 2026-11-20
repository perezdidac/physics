## The march budget bar of a La Processó level, shown under the objective: how much walk the leader has left this turn ("Marxa 340 px"). A green
## fill that turns amber and then red as it empties, with a lighter trail that follows the drop. Pure drawing; TopHud feeds it.
class_name MarchBar
extends Control

var fraction: float = 1.0
var label_text: String = ""
var _trail: float = 1.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_trail = maxf(fraction, _trail - delta * 0.6) if _trail > fraction else fraction
	if visible:
		queue_redraw()


## The fill colour for a fraction of the walk left: green, then amber, then red.
static func fill_color(frac: float) -> Color:
	if frac > 0.5:
		return Color("#8fd26a")
	return Color("#ffc04a").lerp(Color("#ff5a4a"), clampf(1.0 - frac / 0.25, 0.0, 1.0)) if frac > 0.0 else Color("#ff5a4a")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var rr: float = size.y * 0.5
	ViewUtil.fill_round_rect(self, rect.grow(1.2), rr + 1.2, Palette.BRASS_DIM)
	ViewUtil.fill_round_rect(self, rect, rr, Color(0.04, 0.05, 0.08, 0.92))
	var inner: Rect2 = rect.grow(-1.5)
	if _trail > fraction:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), inner.size.y * 0.5, Color(1.0, 0.95, 0.75, 0.7))
	if fraction > 0.0:
		ViewUtil.fill_round_rect(self, Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * fraction), inner.size.y)), inner.size.y * 0.5, fill_color(fraction))
	if label_text != "" and size.y >= 9.0:
		var fs: int = roundi(size.y * 0.7)
		ViewUtil.text(self, label_text, Vector2(size.x * 0.5 + 1.0, size.y * 0.5 + fs * 0.36 + 1.0), fs, Color(0.0, 0.0, 0.0, 0.6))
		ViewUtil.text(self, label_text, Vector2(size.x * 0.5, size.y * 0.5 + fs * 0.36), fs, Palette.INK_ON_BRASS if fraction > 0.5 else Palette.IVORY)
