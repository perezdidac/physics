## Camera of the platformer: follows the egg with a look-ahead in the facing direction, moves smoothly and never leaves the world.
class_name PlatformCamera
extends RefCounted

## World point at the centre of the view.
var pos: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var look: float = 0.0
## When > 0, the view always shows this many world pixels from the top to the bottom (boss arenas, where the whole height matters).
var fixed_height: float = 0.0
## World pixels the view may show above the top of the world (DIG levels: the sky and the hoopoe standing on the surface).
var extra_top: float = 0.0
## True on touch devices (set by the screen): free-follow levels zoom in closer.
var phone: bool = false

const LOOK_AHEAD: float = 110.0
const TARGET_VIEW_HEIGHT: float = 480.0
## With the touch controls (phones) the view shows even less of the world so the egg, pupa or moth is big enough.
const PHONE_VIEW_HEIGHT: float = 420.0
## Same for boss arenas on a phone (the wasp's patrol stays partly in view, the dive marker and the egg fully).
const PHONE_BOSS_VIEW_HEIGHT: float = 560.0
## On phone-sized (logical) heights the view shows less of the world so the egg stays big enough.
const COMPACT_VIEW_HEIGHT: float = 360.0


## Zoom for a view of `view_size` logical pixels: about TARGET_VIEW_HEIGHT world pixels tall.
static func zoom_for(view_size: Vector2, on_phone: bool = false) -> float:
	if on_phone:
		return clampf(view_size.y / (COMPACT_VIEW_HEIGHT if view_size.y < 300.0 else PHONE_VIEW_HEIGHT), 0.5, 2.0)
	return clampf(view_size.y / (COMPACT_VIEW_HEIGHT if view_size.y < 300.0 else TARGET_VIEW_HEIGHT), 0.5, 1.6)


func _zoom(view_size: Vector2) -> float:
	return clampf(view_size.y / fixed_height, 0.4, 2.0 if phone else 1.6) if fixed_height > 0.0 else zoom_for(view_size, phone)


## Puts the camera on `target` at once (level start, respawn).
func snap(target: Vector2, view_size: Vector2, world: Vector2) -> void:
	zoom = _zoom(view_size)
	look = 0.0
	pos = clamped(target + Vector2(0.0, -30.0), view_size, world)


## One smooth step towards `target` (the egg centre). `facing` is -1 or 1, `speed` the horizontal speed in px/s.
func follow(dt: float, target: Vector2, facing: float, speed: float, view_size: Vector2, world: Vector2) -> void:
	zoom = _zoom(view_size)
	var want_look: float = facing * LOOK_AHEAD * clampf(0.35 + absf(speed) / 220.0, 0.35, 1.0)
	look += (want_look - look) * (1.0 - exp(-dt * 2.5))
	var goal := Vector2(target.x + look, target.y - 30.0)
	var k: Vector2 = Vector2(1.0 - exp(-dt * 5.0), 1.0 - exp(-dt * 4.0))
	pos = Vector2(pos.x + (goal.x - pos.x) * k.x, pos.y + (goal.y - pos.y) * k.y)
	pos = clamped(pos, view_size, world)


## `p` moved so the view stays inside the world (centred when the world is smaller than the view).
func clamped(p: Vector2, view_size: Vector2, world: Vector2) -> Vector2:
	var half: Vector2 = view_size / (2.0 * zoom)
	var out := p
	out.x = world.x * 0.5 if world.x <= half.x * 2.0 else clampf(p.x, half.x, world.x - half.x)
	out.y = world.y * 0.5 if world.y <= half.y * 2.0 else clampf(p.y, half.y - extra_top, world.y - half.y)
	return out


## Position of the world node on screen so that `pos` is at the middle.
func world_offset(view_size: Vector2) -> Vector2:
	return view_size * 0.5 - pos * zoom


## World rectangle currently visible.
func visible_rect(view_size: Vector2) -> Rect2:
	var size: Vector2 = view_size / zoom
	return Rect2(pos - size * 0.5, size)
