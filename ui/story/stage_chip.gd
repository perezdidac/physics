## A picture of one on-screen control for the stage card: a round touch button (with a text, an arrow or the wings), the gold FIRE button
## or a small rounded "pill" (Pass, Switch caterpillar). Drawn like the real touch buttons; it does not react to input.
class_name StageChip
extends Control

enum Kind { ROUND, FIRE, PILL, LEFT, RIGHT, UP, DOWN, WINGS }

var kind: Kind = Kind.ROUND
var text: String = ""
## Diameter (or height, for a pill) in logical px.
var diameter: float = 44.0


static func make(chip_kind: Kind, chip_text: String, d: float) -> StageChip:
	var c := StageChip.new()
	c.kind = chip_kind
	c.text = chip_text
	c.diameter = d
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = c.chip_size()
	return c


## Size of the picture: a circle, or a wider rounded rectangle for a pill.
func chip_size() -> Vector2:
	if kind == Kind.PILL:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(diameter * 0.4)).x
		return Vector2(maxf(diameter * 1.5, w + diameter * 0.7), diameter * 0.82)
	return Vector2(diameter, diameter)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 1.5
	var fire: bool = kind == Kind.FIRE
	var base: Color = Palette.FIRE_BOTTOM if fire else Palette.BTN_BOTTOM
	if kind == Kind.PILL:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(base, 0.7)
		box.border_color = Color(Palette.BRASS_BRIGHT, 0.5)
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(size.y * 0.3))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	else:
		draw_circle(c, r, Color(base, 0.62 if fire else 0.7))
		draw_arc(c, r, 0.0, TAU, 40, Color(Palette.FOCUS_BORDER if fire else Palette.BRASS_BRIGHT, 0.55), 2.0, true)
	var ink: Color = Color.WHITE if fire else Palette.IVORY
	match kind:
		Kind.LEFT, Kind.RIGHT:
			var s: float = r * 0.42
			var dir: float = -1.0 if kind == Kind.LEFT else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s, 0.0), c + Vector2(-dir * s * 0.6, -s), c + Vector2(-dir * s * 0.6, s)]), ink)
		Kind.UP, Kind.DOWN:
			var s2: float = r * 0.42
			var v: float = -1.0 if kind == Kind.UP else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, v * s2), c + Vector2(-s2, -v * s2 * 0.6), c + Vector2(s2, -v * s2 * 0.6)]), ink)
		Kind.WINGS:
			var s3: float = r * 0.5
			for side: float in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(side * s3 * 0.15, s3 * 0.5), c + Vector2(side * s3 * 1.25, -s3 * 0.9), c + Vector2(side * s3 * 1.0, -s3 * 0.1), c + Vector2(side * s3 * 0.55, s3 * 0.55)]), ink)
		_:
			_draw_text(ink, r)


func _draw_text(ink: Color, r: float) -> void:
	var font: Font = get_theme_font("font", "TitleBlackLabel" if kind == Kind.FIRE else "BodyBoldLabel")
	var fs: int = int(clampf(r * (0.5 if kind == Kind.PILL else 0.4), 9.0, 30.0))
	while fs > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x * 0.86:
		fs -= 1
	var y: float = size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, ink)
