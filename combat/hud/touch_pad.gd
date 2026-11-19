## The on-screen buttons of the touch controls in the battle, in two phases (the player switches with `set_aim`):
## - MOVE: big walk arrows bottom-left, Salt and Mortal bottom-right, the weapon picker and the "Aim" button beside them.
## - AIM: the big FIRE button bottom-right with the weapon picker above it, and "Move" bottom-left.
## Re-centre is shown in both. Dragging on the map is handled by CombatInput (pan in MOVE, rotate the aim in AIM).
class_name TouchPad
extends Control

var fire_button: TouchButton
var jump_button: TouchButton
var flip_button: TouchButton
var weapon_button: TouchButton
var center_button: TouchButton
## El Bolsó: weaves the nest back together (only shown next to a damaged nest, see BottomHud).
var repair_button: TouchButton
var left_button: TouchButton
var right_button: TouchButton
## MOVE -> AIM.
var aim_button: TouchButton
## AIM -> MOVE.
var move_button: TouchButton
## True in the AIM phase (the layout of the weapon button depends on it).
var aim_phase: bool = false
var _last_vp: Vector2 = Vector2.ZERO
var _last_scale: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_button = _add(TouchButton.Style.FIRE, tr("FIRE_DEFAULT"), "")
	jump_button = _add(TouchButton.Style.NORMAL, tr("HUD_JUMP"), tr("HUD_JUMP_TOOLTIP"))
	flip_button = _add(TouchButton.Style.NORMAL, tr("HUD_FLIP"), tr("HUD_FLIP_TOOLTIP"))
	weapon_button = _add(TouchButton.Style.NORMAL, "", "")
	center_button = _add(TouchButton.Style.NORMAL, tr("HUD_CENTER"), tr("HUD_CENTER_TOOLTIP"))
	repair_button = _add(TouchButton.Style.NORMAL, tr("HUD_REPAIR"), tr("HUD_REPAIR_TOOLTIP"))
	repair_button.visible = false
	left_button = _add(TouchButton.Style.NORMAL, "◀", "")
	right_button = _add(TouchButton.Style.NORMAL, "▶", "")
	aim_button = _add(TouchButton.Style.NORMAL, tr("TOUCH_AIM_BUTTON"), "")
	move_button = _add(TouchButton.Style.NORMAL, tr("TOUCH_MOVE_BUTTON"), "")


func _add(style: TouchButton.Style, label: String, tip: String) -> TouchButton:
	var b := TouchButton.new(style, label)
	if not tip.is_empty():
		b.tooltip_text = tip
	add_child(b)
	return b


## Switches the layout between the MOVE (false) and AIM (true) phase.
func set_aim(on: bool) -> void:
	if on != aim_phase:
		aim_phase = on
		layout(get_viewport_rect().size)


func _process(_delta: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp != _last_vp or not is_equal_approx(TouchMetrics.scale_option(), _last_scale):
		layout(vp)


## Places the buttons for a viewport of size `vp`. Every button is at least about 12 mm of real screen (see TouchMetrics);
## if a phase does not fit the lower 66% of the screen, or its width, everything shrinks together. Buttons of different
## phases may share a spot, only the ones of one phase are visible together.
func layout(vp: Vector2) -> void:
	_last_vp = vp
	_last_scale = TouchMetrics.scale_option()
	var f: float = TouchMetrics.fire_size(vp)
	var m: float = TouchMetrics.margin(vp)
	var ins: Vector4 = TouchMetrics.safe_insets(vp) # rounded corners / camera hole
	var ml: float = m + ins.x
	var mr: float = m + ins.z
	var gap: float = m * 0.6
	var a: float = TouchMetrics.sized(TouchMetrics.ARROW_MM, f * 0.8, vp)
	var j: float = TouchMetrics.sized(TouchMetrics.JUMP_MM, f * 0.66, vp)
	var w: float = TouchMetrics.sized(TouchMetrics.MIN_MM, f * 0.66, vp)
	var fl: float = TouchMetrics.sized(TouchMetrics.MIN_MM, f * 0.52, vp)
	var rp: float = TouchMetrics.sized(TouchMetrics.MIN_MM, f * 0.6, vp)
	var c: float = TouchMetrics.sized(TouchMetrics.MIN_MM, f * 0.46, vp)
	var need_h: float = m + maxf(maxf(f + gap + w, j + gap + fl), a + gap + c)
	var need_w: float = 2.0 * m + maxf(2.0 * a + gap + 3.0 * gap + j + w + rp, f + gap + w + gap + c)
	var k: float = minf(1.0, minf(vp.y * 0.66 / need_h, vp.x * 0.62 / need_w))
	var lo: float = minf(1.0, TouchMetrics.scale_option())
	var base: float = TouchMetrics.FIRE_MIN_PX * lo
	f = maxf(f * k, base)
	a = maxf(a * k, base * 0.8)
	j = maxf(j * k, base * 0.66)
	w = maxf(w * k, base * 0.66)
	fl = maxf(fl * k, base * 0.52)
	rp = maxf(rp * k, base * 0.6)
	c = maxf(c * k, base * 0.46)
	var bottom: float = vp.y - m - ins.w
	# MOVE: arrows left, Salt/Mortal in the last column, picker and Aim in the one before.
	_place(left_button, Vector2(ml, bottom - a), a)
	_place(right_button, Vector2(ml + a + gap, bottom - a), a)
	var jump_pos := Vector2(vp.x - mr - j, bottom - j)
	_place(jump_button, jump_pos, j)
	_place(flip_button, Vector2(jump_pos.x + (j - fl) * 0.5, jump_pos.y - gap - fl), fl)
	var col_x: float = jump_pos.x - gap - w
	_place(aim_button, Vector2(col_x, bottom - w), w)
	_place(repair_button, Vector2(col_x - gap - rp, bottom - rp), rp)
	var fire_pos := Vector2(vp.x - mr - f, bottom - f)
	_place(fire_button, fire_pos, f)
	if aim_phase:
		_place(weapon_button, Vector2(fire_pos.x + (f - w) * 0.5, fire_pos.y - gap - w), w)
		_place(move_button, Vector2(ml, bottom - w), w)
		_place(center_button, Vector2(ml, bottom - w - gap - c), c)
	else:
		_place(weapon_button, Vector2(col_x, bottom - w - gap - w), w)
		_place(move_button, Vector2(ml, bottom - w), w)
		_place(center_button, Vector2(ml, bottom - a - gap - c), c)


func _place(b: TouchButton, pos: Vector2, d: float) -> void:
	b.position = pos
	b.set_diameter(d)
