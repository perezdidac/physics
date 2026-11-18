## Camera of the battle (port of getCameraTransform / screenToWorld and the camera-target part of the JS loop).
## Pure maths + state: no nodes. CombatScreen feeds it the sim each frame and applies the result to the world root.
class_name CameraRig
extends RefCounted

const TERRAIN_W: float = 3200.0
const PH_TURN_PLAY: int = 0
const PH_RETREAT: int = 1
const PH_ACTION_WAIT: int = 2
const PH_TURN_DELAY: int = 3

var x: float = 1600.0
var y: float = 400.0
var target_x: float = 1600.0
var target_y: float = 400.0
var pan_x: float = 0.0
var pan_y: float = 0.0
var zoom: float = 1.0
var target_zoom: float = 1.0
var mouse_off: Vector2 = Vector2.ZERO
var smooth_mouse: Vector2 = Vector2.ZERO
## Player zoom multiplier (0.50..2.25).
var user_zoom: float = 1.22
## Impact camera (set by the sim `camera_focus` signal, cleared at turn start).
var impact_active: bool = false
var impact_pos: Vector2 = Vector2(1600, 400)
var impact_tracked: Variant = null
## True while the match is being played (JS appStage == 'PLAYING').
var playing: bool = true
## Debug / capture: when true the camera stays where it is.
var locked: bool = false


## CSS-like base scale for the viewport size (renderer.js:8-20).
static func base_scale(view: Vector2) -> float:
	var is_portrait: bool = view.x < view.y and view.x <= 820.0
	var is_landscape_mobile: bool = view.y <= 540.0 and view.x > view.y
	if is_portrait:
		return clampf(view.x / 600.0, 0.56, 0.86)
	if is_landscape_mobile:
		return clampf(minf(view.x / 1220.0, view.y / 580.0), 0.54, 0.88)
	return clampf(minf(view.x / 1620.0, view.y / 760.0), 0.85, 1.45)


## Returns {scale, cx, cy} (the JS getCameraTransform without the DPR factor).
func get_transform(view: Vector2) -> Dictionary:
	var is_portrait: bool = view.x < view.y and view.x <= 820.0
	var s: float = base_scale(view) * zoom * user_zoom
	var portrait_off: float = 42.0 if (is_portrait and playing) else 0.0
	return {"scale": s, "cx": x + smooth_mouse.x, "cy": y + smooth_mouse.y + portrait_off}


## Screen (logical px) -> world.
func screen_to_world(screen: Vector2, view: Vector2) -> Vector2:
	var xf: Dictionary = get_transform(view)
	var s: float = xf["scale"]
	return Vector2((screen.x - view.x * 0.5) / s + float(xf["cx"]), (screen.y - view.y * 0.5) / s + float(xf["cy"]))


## World -> screen.
func world_to_screen(w: Vector2, view: Vector2) -> Vector2:
	var xf: Dictionary = get_transform(view)
	var s: float = xf["scale"]
	return view * 0.5 + (w - Vector2(float(xf["cx"]), float(xf["cy"]))) * s


## Mouse parallax offset (main.js:496-501) from a normalised cursor position 0..1.
func set_mouse_parallax(norm: Vector2) -> void:
	mouse_off = Vector2((norm.x - 0.5) * 36.0, (norm.y - 0.5) * 18.0)


## Adds a pan delta in world px, with the JS clamps.
func pan_by(dx: float, dy: float) -> void:
	pan_x = clampf(pan_x + dx, -TERRAIN_W * 0.85, TERRAIN_W * 0.85)
	pan_y = clampf(pan_y + dy, -360.0, 320.0)


## Zero the pan offsets (V / Home / "Centra").
func reset_pan() -> void:
	pan_x = 0.0
	pan_y = 0.0


## Multiplies / adds to the user zoom with the JS clamp.
func zoom_user(add: float = 0.0, mul: float = 1.0) -> void:
	user_zoom = clampf(user_zoom * mul + add, 0.50, 2.25)


## Called by CombatScreen on `camera_focus`.
func focus(p: Vector2, fighter: Variant) -> void:
	impact_active = true
	impact_pos = p
	if fighter != null:
		impact_tracked = fighter


## Called at turn start.
func clear_impact() -> void:
	impact_active = false
	impact_tracked = null


## Picks the camera target (main.js:293-339 and 340-344) from the sim state.
## `moving_keys` is true while left/right/up are held (pan offset decays back to the fighter).
func update_targets(sim: Object, t_now: float, slow_mo: bool, moving_keys: bool, aiming_airstrike: bool) -> void:
	if locked:
		return
	if not playing:
		target_x = TERRAIN_W * 0.5 + sin(t_now * 0.24) * 580.0
		target_y = 380.0 + cos(t_now * 0.2) * 30.0
		target_zoom = 0.96
		return
	var water_y: float = _water_y(sim)
	var fighters: Array = ViewUtil.g(sim, "fighters", [])
	var projectiles: Array = ViewUtil.g(sim, "projectiles", [])
	var planes: Array = ViewUtil.g(sim, "airstrike_planes", [])
	var phase: int = ViewUtil.gi(sim, "turn_phase", PH_TURN_PLAY)
	if impact_active and (phase == PH_ACTION_WAIT or phase == PH_TURN_DELAY):
		_follow_moving_fighters(fighters, water_y)
	var drowning: Variant = null
	for f in fighters:
		if ViewUtil.gb(f, "alive") and ViewUtil.gb(f, "drowning"):
			drowning = f
			break
	var active: Variant = ViewUtil.g(sim, "active_fighter")
	if projectiles.size() > 0:
		var p: Variant = projectiles[projectiles.size() - 1]
		pan_x = 0.0
		pan_y = 0.0
		impact_active = true
		impact_pos = ViewUtil.pos(p)
		target_x = clampf(ViewUtil.gf(p, "x"), 220.0, TERRAIN_W - 220.0)
		target_y = clampf(ViewUtil.gf(p, "y"), 160.0, 560.0)
		target_zoom = 1.16 if slow_mo else 1.00
	elif planes.size() > 0:
		var pl: Variant = planes[0]
		pan_x = 0.0
		pan_y = 0.0
		impact_active = true
		impact_pos = Vector2(ViewUtil.gf(pl, "target_x"), 360.0)
		target_x = clampf(ViewUtil.gf(pl, "target_x"), 220.0, TERRAIN_W - 220.0)
		target_y = 360.0
		target_zoom = 0.96
	elif drowning != null:
		pan_x = 0.0
		pan_y = 0.0
		impact_active = true
		impact_pos = Vector2(ViewUtil.gf(drowning, "x"), water_y - 40.0)
		target_x = clampf(ViewUtil.gf(drowning, "x"), 220.0, TERRAIN_W - 220.0)
		target_y = clampf(water_y - 40.0, 240.0, 580.0)
		target_zoom = 1.14
	elif impact_active and (phase == PH_ACTION_WAIT or phase == PH_TURN_DELAY):
		pan_x = 0.0
		pan_y = 0.0
		target_x = clampf(impact_pos.x, 220.0, TERRAIN_W - 220.0)
		target_y = clampf(impact_pos.y, 160.0, 560.0)
		target_zoom = 1.18 if slow_mo else 1.08
	elif active != null and ViewUtil.gb(active, "alive"):
		if moving_keys and not aiming_airstrike:
			pan_x = lerpf(pan_x, 0.0, 0.14)
			pan_y = lerpf(pan_y, 0.0, 0.14)
		target_x = clampf(ViewUtil.gf(active, "x") + pan_x, 200.0, TERRAIN_W - 200.0)
		target_y = clampf(ViewUtil.gf(active, "y") - 35.0 + pan_y, 150.0, 580.0)
		target_zoom = 1.20 if slow_mo else 1.08


func _follow_moving_fighters(fighters: Array, water_y: float) -> void:
	var xf: Variant = impact_tracked
	if xf != null and ViewUtil.gb(xf, "alive") and (not ViewUtil.gb(xf, "grounded", true) or ViewUtil.gb(xf, "sliding") or ViewUtil.gb(xf, "drowning")):
		impact_pos.x = ViewUtil.gf(xf, "x")
		impact_pos.y = (water_y - 30.0) if ViewUtil.gb(xf, "drowning") else ViewUtil.gf(xf, "y") - 24.0
		return
	var best: Variant = null
	var best_d: float = 520.0
	for f in fighters:
		if ViewUtil.gb(f, "alive") and (not ViewUtil.gb(f, "grounded", true) or ViewUtil.gb(f, "sliding") or ViewUtil.gb(f, "drowning")):
			var d: float = ViewUtil.pos(f).distance_to(impact_pos)
			if d < best_d:
				best_d = d
				best = f
	if best != null:
		impact_tracked = best
		impact_pos.x = ViewUtil.gf(best, "x")
		impact_pos.y = (water_y - 30.0) if ViewUtil.gb(best, "drowning") else ViewUtil.gf(best, "y") - 24.0


## Smooths the camera towards the target with the frame-rate independent JS formula (uses the unscaled dt).
func step(raw_dt: float) -> void:
	if locked:
		return
	var k: float = ViewUtil.cam_lerp(raw_dt)
	x = lerpf(x, target_x, k)
	y = lerpf(y, target_y, k)
	zoom = lerpf(zoom, target_zoom, k)
	smooth_mouse = smooth_mouse.lerp(mouse_off, k)


static func _water_y(sim: Object) -> float:
	var terrain: Variant = ViewUtil.g(sim, "terrain")
	return ViewUtil.gf(terrain, "water_y", 700.0)
