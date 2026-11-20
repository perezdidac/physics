## One caterpillar of a squad panel: name over a thin health bar (.worm-pip). Click selects/peeks the caterpillar.
class_name HpPip
extends Control

signal pressed(fighter: Variant)

var fighter: Variant = null
var team: int = 0
var worm_name: String = ""
var fraction: float = 1.0
var is_active: bool = false
var is_dead: bool = false
var _shown_fraction: float = 1.0


func _init() -> void:
	custom_minimum_size = Vector2(44, 17)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets what the pip shows.
func setup(fighter_ref: Variant, team_idx: int, display_name: String, hp_fraction: float, active: bool, dead: bool) -> void:
	var frac: float = clampf(hp_fraction, 0.0, 1.0)
	var changed: bool = team != team_idx or worm_name != display_name or fraction != frac or is_active != active or is_dead != dead
	fighter = fighter_ref
	team = team_idx
	worm_name = display_name
	fraction = frac
	is_active = active
	is_dead = dead
	mouse_default_cursor_shape = Control.CURSOR_ARROW if dead else Control.CURSOR_POINTING_HAND
	if changed:
		queue_redraw()


func _process(delta: float) -> void:
	if not is_equal_approx(_shown_fraction, fraction):
		_shown_fraction = lerpf(_shown_fraction, fraction, clampf(delta * 14.0, 0.0, 1.0))
		if absf(_shown_fraction - fraction) < 0.004:
			_shown_fraction = fraction
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(fighter)
			accept_event()


func _draw() -> void:
	var font: Font = get_theme_font("font", "Label")
	var col: Color = Color.WHITE if is_active else Palette.IVORY_MUTED
	var alpha: float = 0.22 if is_dead else 1.0
	col.a *= alpha
	var txt: String = worm_name
	draw_string(font, Vector2(0, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x, 9, col)
	var bar := Rect2(0, size.y - 5.0, size.x, 4.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(2)
	sb.bg_color = Color(1, 1, 1, 0.12 * alpha)
	draw_style_box(sb, bar)
	var w: float = bar.size.x * (0.0 if is_dead else _shown_fraction)
	if w >= 1.0:
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(2)
		fill.bg_color = Color(Palette.team_color(team), alpha)
		draw_style_box(fill, Rect2(bar.position, Vector2(w, bar.size.y)))
