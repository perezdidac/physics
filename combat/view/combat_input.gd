## Human input controller of the battle (keyboard, mouse, touch gestures, on-screen button hooks). Translates what the
## player does into CombatSim command methods and camera moves (port of the handlers in main.js:496-1000, 1187-1614).
class_name CombatInput
extends Node

## Emitted for things that belong to the screen router / HUD rather than to the sim.
signal restart_requested
signal ripple_requested(world_or_screen: Vector2, label: String, color: Color, is_world: bool)
signal sound_requested(sfx_name: String)

const DOUBLE_PRESS_MS: int = 360
const LONG_PRESS_MS: int = 250
const SWIPE_PX: float = 9.0

var sim: Object = null
var cam: CameraRig = null
## Drawer state is owned by the HUD; the screen mirrors it here (aim keys are ignored while it is open).
var drawer_open: bool = false
## Set by the screen: true while a rotate prompt or any modal blocks the game input.
var blocked: bool = false

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
var _press_ms: int = 0
var _tap_count: int = 0
var _tap_ms: int = 0
var _pinch_last: float = 0.0
var _block_mouse_until: int = 0


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
	if _gesture == "PENDING" and _now() - _press_ms >= LONG_PRESS_MS:
		_gesture = "SHOOT"
		if _can_act():
			_call("begin_charge_or_fire")


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
			_gesture = "PENDING"
			_gesture_start = e.position
			_press_ms = _now()
		else:
			_enter_pan()
	else:
		_touches.erase(e.index)
		if _touches.is_empty():
			_touch_end(e.position)


func _enter_pan() -> void:
	if _gesture == "SHOOT" or _is_charging():
		_call("release_charge")
	_gesture = "PAN"
	_keys["left"] = false
	_keys["right"] = false
	var pts: Array = _touches.values()
	if pts.size() >= 2:
		_pinch_last = (pts[0] as Vector2).distance_to(pts[1])


func _is_charging() -> bool:
	return ViewUtil.gb(sim, "is_charging")


func _on_drag(e: InputEventScreenDrag) -> void:
	_block_mouse_until = _now() + 280
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
	var human: bool = _can_act()
	var total: Vector2 = e.position - _gesture_start
	if _gesture == "PENDING" and total.length() > SWIPE_PX:
		_cancel_charge()
		_gesture = "SWIPE_AIM" if absf(total.y) > absf(total.x) * 1.08 else "SWIPE_WALK"
	match _gesture:
		"SWIPE_AIM":
			if human:
				cam.pan_x = lerpf(cam.pan_x, 0.0, 0.2)
				cam.pan_y = lerpf(cam.pan_y, 0.0, 0.2)
				_nudge_pitch(e.relative.y * 0.0085)
			else:
				_pan_by_screen(e.relative)
		"SWIPE_WALK":
			if human:
				if _is_airstrike() and absf(e.relative.x) > 0.5:
					var vs: Vector2 = get_viewport().get_visible_rect().size
					var s: float = float(cam.get_transform(vs)["scale"])
					var mw: Variant = ViewUtil.g(sim, "mouse_world", Vector2.ZERO)
					_call("set_target", [Vector2(mw.x + e.relative.x / s, mw.y)])
				elif total.length() > 6.0:
					_keys["left"] = total.x < 0.0
					_keys["right"] = total.x > 0.0
			else:
				_pan_by_screen(e.relative)
		"SHOOT":
			if absf(e.relative.y) > 0.4:
				_nudge_pitch(e.relative.y * 0.0065)


## Touch swipe aiming changes the pitch by a delta (clamped by the sim).
func _nudge_pitch(delta: float) -> void:
	_call("nudge_aim_pitch", [delta])


func _cancel_charge() -> void:
	if _is_charging():
		_call("release_charge")


func _touch_end(pos: Vector2) -> void:
	var mode: String = _gesture
	_gesture = "NONE"
	_keys["left"] = false
	_keys["right"] = false
	if mode == "SHOOT":
		_call("release_charge")
		return
	if mode != "PENDING":
		return
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
	elif _tap_count == 2:
		do_forward_jump()
		ripple_requested.emit(pos, ViewUtil.tr_text("TOUCH_JUMP"), ViewColors.WARM_YELLOW, false)
	else:
		do_forward_jump()
		ripple_requested.emit(pos, ViewUtil.tr_text("TOUCH_BACKFLIP"), ViewColors.h("#ff8b3d"), false)
		_tap_count = 0
