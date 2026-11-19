## On-screen controls of the platformer: big semi-transparent left and right arrows at the bottom left and a big JUMP button at the
## bottom right. Multi-touch: every finger is tracked on its own, so hold-right plus tap-jump works. Shown on touch devices only.
class_name PlatformTouchPad
extends Control

## Fired on the frame a finger lands on JUMP (the screen latches it so very short taps are not lost).
signal jump_pressed

## Show the pad even without a touchscreen (tests, screenshots).
var force_show: bool = false
## Level mode: "" (egg platformer), "DIG" (the arrows dig into the soil; JUMP is a small hop) or "FLY" (JUMP is a wing flap, hold to glide).
var mode: String = ""
var _fingers: Dictionary = {}

const MARGIN: float = 20.0
const GAP: float = 14.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Options.button_size_changed.connect(queue_redraw)


## Text of the big button for the current mode.
func jump_label() -> String:
	return tr("PLAT_FLAP") if mode == "FLY" else tr("PLAT_JUMP")


## Short caption above the arrows ("hold to dig"), empty outside DIG mode.
func arrows_caption() -> String:
	return tr("PLAT_PAD_DIG") if mode == "DIG" else ""


## True when the pad is drawn and active.
func is_shown() -> bool:
	return force_show or UiUtil.touch_seen or DisplayServer.is_touchscreen_available()


## Edge of the arrow buttons in viewport units: about 14 mm of real screen times the button size option (see TouchMetrics).
func button_size() -> float:
	var vp: Vector2 = get_viewport_rect().size if is_inside_tree() else size
	return TouchMetrics.platform_button(vp)


## Safe insets (left, top, right, bottom): rounded screen corners and the camera hole (see TouchMetrics.safe_insets).
func _insets() -> Vector4:
	return TouchMetrics.safe_insets(get_viewport_rect().size if is_inside_tree() else size)


func left_rect() -> Rect2:
	var b: float = button_size()
	var ins: Vector4 = _insets()
	return Rect2(MARGIN + ins.x, size.y - MARGIN - ins.w - b, b, b)


func right_rect() -> Rect2:
	var b: float = button_size()
	var col: float = 2.0 if mode == "DIG" else 1.0
	var ins: Vector4 = _insets()
	return Rect2(MARGIN + ins.x + (b + GAP) * col, size.y - MARGIN - ins.w - b, b, b)


## DIG mode: the down arrow between left and right (inverted T).
func down_rect() -> Rect2:
	var b: float = button_size()
	var ins: Vector4 = _insets()
	return Rect2(MARGIN + ins.x + b + GAP, size.y - MARGIN - ins.w - b, b, b)


## DIG mode: the up arrow above the down arrow.
func up_rect() -> Rect2:
	var b: float = button_size()
	var ins: Vector4 = _insets()
	return Rect2(MARGIN + ins.x + b + GAP, size.y - MARGIN - ins.w - b * 2.0 - GAP, b, b)


func jump_rect() -> Rect2:
	var b: float = button_size() * 1.3
	var ins: Vector4 = _insets()
	return Rect2(size.x - MARGIN - ins.z - b, size.y - MARGIN - ins.w - b, b, b)


## True while any finger holds the left arrow.
func left() -> bool:
	return _fingers.values().has("left")


## True while any finger holds the right arrow.
func right() -> bool:
	return _fingers.values().has("right")


## True while any finger holds the up arrow (DIG mode only).
func up_held() -> bool:
	return _fingers.values().has("up")


## True while any finger holds the down arrow (DIG mode only).
func down_held() -> bool:
	return _fingers.values().has("down")


## True while any finger holds JUMP.
func jump() -> bool:
	return _fingers.values().has("jump")


## Which control is under `p` ("left", "right", "jump" or ""); fingers slide freely between the two arrows.
func zone_at(p: Vector2) -> String:
	var pad: float = 14.0
	# A finger right on an arrow beats the extra margin around JUMP (they can overlap on small screens).
	for z: String in (["left", "right", "up", "down"] if mode == "DIG" else ["left", "right"]):
		if _zone_rect(z).has_point(p):
			return z
	if jump_rect().grow(pad + 10.0).has_point(p):
		return "jump"
	var l: Rect2 = left_rect()
	var r: Rect2 = right_rect()
	if mode == "DIG":
		var cluster: Rect2 = l.merge(r).merge(up_rect()).grow(pad)
		if not cluster.has_point(p):
			return ""
		var best: String = ""
		var best_d: float = INF
		for z: String in ["left", "right", "up", "down"]:
			var d: float = _zone_rect(z).get_center().distance_to(p)
			if d < best_d:
				best_d = d
				best = z
		return best
	var both: Rect2 = l.merge(r).grow(pad)
	both.position.y -= 40.0
	both.size.y += 40.0
	if both.has_point(p):
		return "left" if p.x < (l.end.x + r.position.x) * 0.5 else "right"
	return ""


func _zone_rect(z: String) -> Rect2:
	match z:
		"left":
			return left_rect()
		"right":
			return right_rect()
		"up":
			return up_rect()
	return down_rect()


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var z: String = zone_at(touch.position) # before touch_seen: the first touch must hit what was drawn
			UiUtil.touch_seen = true
			_fingers[touch.index] = z
			if z == "jump":
				jump_pressed.emit()
		else:
			UiUtil.touch_seen = true
			_fingers.erase(touch.index)
		_refresh()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _fingers.has(drag.index):
		var z2: String = zone_at(drag.position)
		var old: String = _fingers[drag.index]
		if z2 != "" and not (old == "jump" and z2 != "jump"):
			if z2 == "jump" and old != "jump":
				jump_pressed.emit()
			_fingers[drag.index] = z2
		elif z2 == "" and old != "jump":
			_fingers[drag.index] = ""
		_refresh()


## Releases every finger (pause, end of level).
func release_all() -> void:
	_fingers.clear()
	_refresh()


func _refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if not is_shown():
		return
	_draw_arrow(left_rect(), -1.0, left())
	_draw_arrow(right_rect(), 1.0, right())
	if mode == "DIG":
		_draw_arrow(up_rect(), 0.0, up_held(), -1.0)
		_draw_arrow(down_rect(), 0.0, down_held(), 1.0)
	var jr: Rect2 = jump_rect()
	var down: bool = jump()
	var c: Vector2 = jr.get_center()
	var rad: float = jr.size.x * 0.5
	draw_circle(c, rad, Color(0.06, 0.07, 0.1, 0.34 if not down else 0.5))
	draw_circle(c, rad - 5.0, Color(0.96, 0.78, 0.3, 0.2 if not down else 0.5))
	draw_arc(c, rad, 0.0, TAU, 40, Color(0.96, 0.81, 0.47, 0.6), 3.0, true)
	var a := Color(0.95, 0.93, 0.87, 0.9)
	var s: float = rad * 0.32
	if mode == "FLY":
		_draw_wings(c + Vector2(0.0, -8.0), s, a, down)
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s - 8.0), c + Vector2(s, s * 0.25 - 8.0), c + Vector2(-s, s * 0.25 - 8.0)]), a)
	ViewUtil.text(self, jump_label(), c + Vector2(0.0, rad * 0.58), int(rad * 0.3), a)
	var cap: String = arrows_caption()
	if cap != "":
		var u: Rect2 = up_rect()
		ViewUtil.text(self, cap, Vector2(u.get_center().x, u.position.y - 8.0), 14, Color(0.95, 0.93, 0.87, 0.75))


## Two raised wings for the flap button (`down` = pressed: the wings sweep down).
func _draw_wings(c: Vector2, s: float, col: Color, down: bool) -> void:
	var dip: float = s * 0.9 if down else 0.0
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([c + Vector2(side * s * 0.15, s * 0.5), c + Vector2(side * s * 1.25, -s * 0.9 + dip), c + Vector2(side * s * 1.0, -s * 0.1 + dip * 0.6), c + Vector2(side * s * 0.55, s * 0.55)])
		draw_colored_polygon(pts, col)


func _draw_arrow(r: Rect2, dir: float, down: bool, vdir: float = 0.0) -> void:
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.5
	draw_circle(c, rad, Color(0.06, 0.07, 0.1, 0.34 if not down else 0.5))
	if down:
		draw_circle(c, rad - 5.0, Color(0.96, 0.78, 0.3, 0.45))
	draw_arc(c, rad, 0.0, TAU, 40, Color(0.96, 0.81, 0.47, 0.6), 3.0, true)
	var s: float = rad * 0.4
	var col := Color(0.95, 0.93, 0.87, 0.9)
	if vdir != 0.0:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, vdir * s), c + Vector2(-s, -vdir * s * 0.6), c + Vector2(s, -vdir * s * 0.6)]), col)
		return
	draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s, 0.0), c + Vector2(-dir * s * 0.6, -s), c + Vector2(-dir * s * 0.6, s)]), col)
