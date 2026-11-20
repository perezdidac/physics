## Human input controller of the battle (keyboard, mouse, touch gestures, on-screen button hooks). Translates what the
## player does into CombatSim command methods and camera moves (port of the handlers in main.js:496-1000, 1187-1614).
##
## Touch scheme (one finger, tracked in `_touches`; touches on on-screen buttons never reach this node). Walking is done
## by the arrow buttons of the HUD (`set_key`), never by gestures. What a finger on the map does depends on the phase
## (`touch_aim`, set by BottomHud):
## - MOVE: a drag pans the camera, a quick release is a tap (switch ally, double tap = jump, triple tap = backflip).
## - AIM: a drag anywhere rotates the aim angle (relative, it flips the facing over the top); a tap sets the airstrike target.
##   Releasing does not fire (the FIRE button does). With the airstrike selected a drag pans instead.
## - PAN: two or more fingers (pan and pinch zoom); it cancels any aim drag and never moves the caterpillar.
class_name CombatInput
extends Node

## Emitted for things that belong to the screen router / HUD rather than to the sim.
signal restart_requested
signal ripple_requested(world_or_screen: Vector2, label: String, color: Color, is_world: bool)
signal sound_requested(sfx_name: String)
## Aim-drag feedback: the caterpillar's screen position, the finger, and the aim angle in degrees (up is positive).
signal aim_drag_changed(active: bool, from: Vector2, to: Vector2, degrees: float)

const DOUBLE_PRESS_MS: int = 360
const SWIPE_PX: float = 9.0
## A finger drag of this fraction of the viewport height turns the aim by one radian.
const AIM_DRAG_FRACTION: float = 0.22
## Length of the aim line drawn while dragging, in pixels.
const AIM_LINE_PX: float = 130.0

var sim: Object = null
var cam: CameraRig = null
## Drawer state is owned by the HUD; the screen mirrors it here (aim keys are ignored while it is open).
var drawer_open: bool = false
## Set by the screen: true while a rotate prompt or any modal blocks the game input.
var blocked: bool = false
## Touch AIM phase (true) or MOVE phase (false), mirrored from the HUD.
var touch_aim: bool = false

var _keys: Dictionary = {"left": false, "right": false, "up": false, "down": false}
var _pan_keys: Dictionary = {"left": false, "right": false, "up": false, "down": false}
var _shift: bool = false
var _last_move: int = 0
var _last_aim: int = 0
var _last_glide: bool = false
var _argc_cache: Dictionary = {}
# mouse
var _mouse_down: bool = false
var _mouse_start: Vector2 = Vector2.ZERO
var _mouse_moved: float = 0.0
# touch
var _touches: Dictionary = {}
var _gesture: String = "NONE"
var _gesture_start: Vector2 = Vector2.ZERO
var _gesture_moved: float = 0.0
var _tap_count: int = 0
var _tap_ms: int = 0
var _pinch_last: float = 0.0
var _block_mouse_until: int = 0


func _ready() -> void:
	add_to_group("combat_input")


# ---------------------------------------------------------------- helpers

func _has(cmd: String) -> bool:
	_call_info(cmd)
	return int(_argc_cache[cmd]) >= 0


func _call_info(cmd: String) -> void:
	if not _argc_cache.has(cmd):
		var n: int = -1
		for m in sim.get_method_list():
			if m["name"] == cmd:
				n = (m["args"] as Array).size()
				break
		_argc_cache[cmd] = n


## Calls a sim command if it exists (extra arguments are dropped when the sim method takes fewer).
func _call(cmd: String, args: Array = []) -> Variant:
	if sim == null:
		return null
	_call_info(cmd)
	var n_args: int = _argc_cache[cmd]
	if n_args < 0:
		return null
	return sim.callv(cmd, args.slice(0, mini(args.size(), n_args)))


func _phase() -> int:
	return ViewUtil.gi(sim, "turn_phase", 0)


func _active() -> Variant:
	return ViewUtil.g(sim, "active_fighter")


func _is_human_turn() -> bool:
	if sim == null or not ViewUtil.gb(sim, "playing", true):
		return false
	if _phase() == ViewCtx.PH_GAME_OVER:
		return false
	return not bool(_call("is_current_turn_ai"))


func _can_act() -> bool:
	var a: Variant = _active()
	var ph: int = _phase()
	return _is_human_turn() and a != null and ViewUtil.gb(a, "alive") and not ViewUtil.gb(a, "drowning") \
		and (ph == ViewCtx.PH_TURN_PLAY or ph == ViewCtx.PH_RETREAT)


func _weapon_idx() -> int:
	return ViewUtil.gi(sim, "selected_weapon_idx")


func _is_airstrike() -> bool:
	return _weapon_idx() == 10


func _now() -> int:
	return Time.get_ticks_msec()


# ---------------------------------------------------------------- per-frame

## Called every frame by the screen with the unscaled dt: camera pan keys and held-key forwarding to the sim.
func tick(raw_dt: float) -> void:
	if sim == null or cam == null:
		return
	if _shift:
		var px: int = int(_pan_keys["right"]) - int(_pan_keys["left"])
		var py: int = int(_pan_keys["down"]) - int(_pan_keys["up"])
		if px != 0 or py != 0:
			cam.pan_by(float(px) * 560.0 * raw_dt, float(py) * 420.0 * raw_dt)
	var move: int = 0
	var aim: int = 0
	var glide: bool = false
	if _can_act() and not blocked:
		move = int(_keys["right"]) - int(_keys["left"])
		if not _shift and not drawer_open:
			aim = int(_keys["down"]) - int(_keys["up"])
		glide = bool(_keys["up"]) and not _shift
	if move != _last_move:
		_last_move = move
		_call("set_move", [move])
	if aim != _last_aim:
		_last_aim = aim
		_call("set_aim_input", [aim])
	if glide != _last_glide:
		_last_glide = glide
		_call("set_glide", [glide])


## True while a movement/aim key that returns the pan offset to the fighter is held.
func moving_keys_held() -> bool:
	return bool(_keys["left"]) or bool(_keys["right"]) or bool(_keys["up"])


# ---------------------------------------------------------------- actions (also used by the on-screen buttons)

## Left/right/up/down held state from an on-screen button.
func set_key(cmd: String, held: bool) -> void:
	_keys[cmd] = held
	if cmd == "left" or cmd == "right":
		if held:
			_keys["right" if cmd == "left" else "left"] = false


## Enter / J / the jump button: the sim turns a second press in the air within 0.36 s into a backflip.
func do_forward_jump() -> void:
	if _can_act():
		_call("jump_forward")


func do_backflip() -> void:
	if _can_act():
		_call("jump_backward")


func fire_down() -> void:
	if not ViewUtil.gb(sim, "playing", true):
		return
	if _phase() == ViewCtx.PH_GAME_OVER:
		restart_requested.emit()
		return
	if _is_human_turn():
		_call("begin_charge_or_fire")


func fire_up() -> void:
	if _is_human_turn():
		_call("release_charge")


func switch_worm(ally: Variant = null) -> bool:
	if not _is_human_turn() or _phase() != ViewCtx.PH_TURN_PLAY:
		return false
	var r: Variant = _call("switch_fighter", [ally] if ally != null else [])
	return r == null or bool(r)


func zoom_step(add: float) -> void:
	cam.zoom_user(add)


# ---------------------------------------------------------------- events

## Uses unhandled input so keys the HUD consumed (drawer, weapon keys, Esc, M) never reach the sim twice.
func _unhandled_input(event: InputEvent) -> void:
	if sim == null or blocked:
		return
	if event is InputEventKey:
		_on_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_key(e: InputEventKey) -> void:
	var k: Key = e.keycode
	if not ViewUtil.gb(sim, "playing", true):
		return
	if not e.pressed:
		_on_key_release(k)
		return
	if _phase() == ViewCtx.PH_GAME_OVER:
		return
	if k == KEY_SHIFT:
		_shift = true
		_keys["left"] = false
		_keys["right"] = false
		return
	if k == KEY_PAGEUP:
		cam.zoom_user(0.14)
	elif k == KEY_PAGEDOWN:
		cam.zoom_user(-0.14)
	elif k == KEY_V or k == KEY_HOME:
		cam.reset_pan()
	match k:
		KEY_A, KEY_LEFT:
			if _shift:
				_pan_keys["left"] = true
			else:
				_keys["left"] = true
		KEY_D, KEY_RIGHT:
			if _shift:
				_pan_keys["right"] = true
			else:
				_keys["right"] = true
		KEY_W, KEY_UP:
			if _shift:
				_pan_keys["up"] = true
			else:
				_keys["up"] = true
		KEY_S, KEY_DOWN:
			if _shift:
				_pan_keys["down"] = true
			else:
				_keys["down"] = true
	if e.echo:
		return
	if k == KEY_SPACE:
		if _is_human_turn():
			_call("begin_charge_or_fire")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_J:
		do_forward_jump()
	elif k == KEY_BACKSPACE:
		do_backflip()
	elif k == KEY_TAB:
		switch_worm()
	elif k == KEY_C:
		if _is_human_turn():
			_call("spin_silk_web")
	elif k == KEY_F:
		_call("toggle_convoy")


func _on_key_release(k: Key) -> void:
	match k:
		KEY_SHIFT:
			_shift = false
			for n in _pan_keys:
				_pan_keys[n] = false
		KEY_A, KEY_LEFT:
			_keys["left"] = false
			_pan_keys["left"] = false
		KEY_D, KEY_RIGHT:
			_keys["right"] = false
			_pan_keys["right"] = false
		KEY_W, KEY_UP:
			_keys["up"] = false
			_pan_keys["up"] = false
		KEY_S, KEY_DOWN:
			_keys["down"] = false
			_pan_keys["down"] = false
		KEY_SPACE:
			if _is_human_turn():
				_call("release_charge")


func _on_mouse_button(e: InputEventMouseButton) -> void:
	if _now() < _block_mouse_until:
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		cam.zoom_user(0.08)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		cam.zoom_user(-0.08)
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if _phase() == ViewCtx.PH_GAME_OVER:
				restart_requested.emit()
				return
			_mouse_down = true
			_mouse_start = e.position
			_mouse_moved = 0.0
		else:
			if _mouse_down and _mouse_moved <= 6.0:
				_click_ally(e.position)
			_mouse_down = false


func _on_mouse_motion(e: InputEventMouseMotion) -> void:
	if _now() < _block_mouse_until or not _touches.is_empty():
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	cam.set_mouse_parallax(e.position / vs)
	if _mouse_down:
		_mouse_moved = maxf(_mouse_moved, e.position.distance_to(_mouse_start))
		_pan_by_screen(e.relative)


func _pan_by_screen(delta: Vector2) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var s: float = float(cam.get_transform(vs)["scale"])
	cam.pan_by(-delta.x / s, -delta.y / s)


func _click_ally(screen: Vector2) -> void:
	if not _is_human_turn() or _phase() != ViewCtx.PH_TURN_PLAY or ViewUtil.gb(sim, "has_acted_or_moved_this_turn"):
		return
	var w: Vector2 = cam.screen_to_world(screen, get_viewport().get_visible_rect().size)
	var act: Variant = _active()
	for f in ViewUtil.g(sim, "fighters", []):
		if f != act and ViewUtil.gb(f, "alive") and ViewUtil.gi(f, "team") == ViewUtil.gi(act, "team") \
				and Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - 6.0).distance_to(w) <= 28.0:
			switch_worm(f)
			return


# ---------------------------------------------------------------- touch

func _on_touch(e: InputEventScreenTouch) -> void:
	_block_mouse_until = _now() + 280
	if _phase() == ViewCtx.PH_GAME_OVER and e.pressed:
		restart_requested.emit()
		return
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_begin_single(e.position)
		else:
			_enter_pan()
	elif _touches.has(e.index):
		_touches.erase(e.index)
		if _touches.is_empty():
			_touch_end(e.position)


## First finger down: is an aim drag (AIM phase) or a plain (tap or pan) touch.
func _begin_single(pos: Vector2) -> void:
	_gesture = "PENDING"
	_gesture_start = pos
	_gesture_moved = 0.0
	if touch_aim and _can_act() and _phase() == ViewCtx.PH_TURN_PLAY and not _is_airstrike():
		_gesture = "AIM"


func _active_screen_pos(vs: Vector2) -> Vector2:
	var a: Variant = _active()
	if a == null:
		return Vector2(-1000.0, -1000.0)
	return cam.world_to_screen(Vector2(ViewUtil.gf(a, "x"), ViewUtil.gf(a, "y") - 6.0), vs)


## Two or more fingers: camera gesture. Cancels the aim drag.
func _enter_pan() -> void:
	_end_aim()
	_gesture = "PAN"
	var pts: Array = _touches.values()
	if pts.size() >= 2:
		_pinch_last = (pts[0] as Vector2).distance_to(pts[1])


func _end_aim() -> void:
	if _gesture == "AIM":
		aim_drag_changed.emit(false, Vector2.ZERO, Vector2.ZERO, 0.0)


func _on_drag(e: InputEventScreenDrag) -> void:
	_block_mouse_until = _now() + 280
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		if _gesture != "PAN":
			_enter_pan()
		var pts: Array = _touches.values()
		var d: float = (pts[0] as Vector2).distance_to(pts[1])
		if _pinch_last > 12.0:
			cam.zoom_user(0.0, d / _pinch_last)
		_pinch_last = d
		_pan_by_screen(e.relative * 0.5)
		return
	_gesture_moved = maxf(_gesture_moved, e.position.distance_to(_gesture_start))
	match _gesture:
		"AIM":
			_rotate_aim(e.relative)
		"PENDING":
			if _gesture_moved > SWIPE_PX:
				_gesture = "PAN1"
				_pan_by_screen(e.position - _gesture_start)
		"PAN1":
			_pan_by_screen(e.relative)


## Aim drag: the finger turns the aim direction like a dial (relative, anywhere on the screen). Dragging across the
## aim line rotates it; over the top it flips the facing, so the whole half circle is reachable.
func _rotate_aim(rel: Vector2) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var pitch: float = ViewUtil.gf(sim, "aim_pitch")
	var a: Variant = _active()
	var face: int = -1 if (a != null and ViewUtil.gi(a, "facing", 1) < 0) else 1
	var dir := Vector2(face * cos(pitch), sin(pitch))
	var turn: float = (dir.x * rel.y - dir.y * rel.x) / (vs.y * AIM_DRAG_FRACTION)
	var th: float = dir.angle() + turn
	var new_face: int = 1 if cos(th) >= 0.0 else -1
	if new_face != face:
		_call("set_facing", [new_face])
	_nudge_pitch(atan2(sin(th), absf(cos(th))) - pitch)
	var from: Vector2 = _active_screen_pos(vs)
	var now_pitch: float = ViewUtil.gf(sim, "aim_pitch")
	var line := Vector2(new_face * cos(now_pitch), sin(now_pitch)) * AIM_LINE_PX
	aim_drag_changed.emit(true, from, from + line, rad_to_deg(-now_pitch))


## Touch aiming changes the pitch by a delta (clamped by the sim).
func _nudge_pitch(delta: float) -> void:
	_call("nudge_aim_pitch", [delta])


func _touch_end(pos: Vector2) -> void:
	var mode: String = _gesture
	_end_aim()
	_gesture = "NONE"
	if mode == "PENDING":
		_tap(pos)


func _tap(pos: Vector2) -> void:
	var now: int = _now()
	_tap_count = _tap_count + 1 if now - _tap_ms <= DOUBLE_PRESS_MS else 1
	_tap_ms = now
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var w: Vector2 = cam.screen_to_world(pos, vs)
	if _tap_count == 1:
		if _is_airstrike() and _can_act() and _phase() == ViewCtx.PH_TURN_PLAY:
			_call("set_target", [w])
			sound_requested.emit("tick")
			ripple_requested.emit(pos, ViewUtil.tr_text("TOUCH_TARGET"), ViewColors.AIM_CROSS, false)
		elif _is_human_turn() and _phase() == ViewCtx.PH_TURN_PLAY and not ViewUtil.gb(sim, "has_acted_or_moved_this_turn"):
			var act: Variant = _active()
			for f in ViewUtil.g(sim, "fighters", []):
				if f != act and ViewUtil.gb(f, "alive") and ViewUtil.gi(f, "team") == ViewUtil.gi(act, "team") \
						and Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - 6.0).distance_to(w) <= 32.0:
					if switch_worm(f):
						ripple_requested.emit(pos, ViewUtil.gs(f, "name").to_upper(), ViewColors.WARM_YELLOW, false)
						_tap_count = 0
					return
	elif touch_aim:
		_tap_count = 0
	elif _tap_count == 2:
		do_forward_jump()
		ripple_requested.emit(pos, ViewUtil.tr_text("TOUCH_JUMP"), ViewColors.WARM_YELLOW, false)
	else:
		do_forward_jump()
		ripple_requested.emit(pos, ViewUtil.tr_text("TOUCH_BACKFLIP"), ViewColors.h("#ff8b3d"), false)
		_tap_count = 0
