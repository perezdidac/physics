## Sizes of the touch controls in physical terms (millimetres of the real screen), scaled by the player's "button size"
## option and clamped to what fits the viewport.
## `force` lets tests and screenshot tools switch the touch UI on or off without a touchscreen.
class_name TouchMetrics
extends RefCounted

## -1 = automatic (UiUtil.is_touch_ui), 0 = never, 1 = always.
static var force: int = -1
## > 0 replaces the screen dots per inch (tests and screenshot tools simulating a phone).
static var force_dpi: float = 0.0

## Physical targets (millimetres): every touch control is at least MIN_MM, the main ones bigger.
const MIN_MM := 12.0
const FIRE_MM := 17.0
const JUMP_MM := 14.0
## The walk arrows of the MOVE phase.
const ARROW_MM := 16.0
## Floors in viewport units (the sizes before the physical sizing existed): a control is never smaller than this.
const FIRE_MIN_PX := 110.0
const FIRE_MAX_FRACTION := 0.30
const FALLBACK_DPI := 160.0
## Typical height of a phone screen in landscape, used when the platform reports no real DPI (web browsers say 96).
const PHONE_HEIGHT_INCHES := 2.75


## True when the touch controls must be shown for a viewport of this size.
static func active(vp: Vector2) -> bool:
	if force >= 0:
		return force == 1
	return UiUtil.is_touch_ui(vp)


## The player's button size multiplier (0.85 / 1.0 / 1.25).
static func scale_option() -> float:
	return Options.button_scale()


## Real pixels per viewport unit (content scale and stretch included).
static func pixel_ratio(vp: Vector2) -> float:
	if vp.y <= 0.0 or DisplayServer.window_get_size().y <= 0: # headless: no real window
		return 1.0
	return maxf(0.25, float(DisplayServer.window_get_size().y) / vp.y)


## Dots per inch of the real screen. Web and some desktops report 96 or nothing: on a touch device that is replaced by
## the assumption of a phone-sized screen (window height = 2.75 inches).
static func dpi(vp: Vector2) -> float:
	if force_dpi > 0.0:
		return force_dpi
	var d: float = float(DisplayServer.screen_get_dpi())
	var scale: float = DisplayServer.screen_get_scale()
	if d <= 0.0:
		d = FALLBACK_DPI
	elif scale > 1.0 and d < 110.0:
		d *= scale
	if d <= 110.0 and active(vp):
		d = maxf(d, float(DisplayServer.window_get_size().y) / PHONE_HEIGHT_INCHES)
	return d


## `millimetres` of the real screen in viewport units.
static func mm(millimetres: float, vp: Vector2) -> float:
	return millimetres / 25.4 * dpi(vp) / pixel_ratio(vp)


## A control of `millimetres`, multiplied by the button size option, never below `floor_px` (the floor shrinks only
## with the "small" option).
static func sized(millimetres: float, floor_px: float, vp: Vector2) -> float:
	var s: float = scale_option()
	return maxf(floor_px * minf(1.0, s), mm(millimetres, vp) * s)


## Diameter of the FIRE button: about 17 mm, at least 110 px; the stack of buttons (see TouchPad) fits the viewport.
static func fire_size(vp: Vector2) -> float:
	var s: float = scale_option()
	return minf(sized(FIRE_MM, FIRE_MIN_PX, vp), maxf(FIRE_MIN_PX * minf(1.0, s), vp.y * FIRE_MAX_FRACTION * s))


## Gap between the controls and the screen edge.
static func margin(vp: Vector2) -> float:
	return maxf(10.0, fire_size(vp) * 0.12)


## Size of the rectangular buttons of the bottom bar (switch worm, pass): at least 12 mm high.
static func bar_button_size(vp: Vector2) -> Vector2:
	var h: float = minf(sized(MIN_MM, 40.0, vp), vp.y * 0.16)
	return Vector2(maxf(h * 1.6, 64.0 * minf(1.0, scale_option())), h)


## Edge of the platformer's arrow buttons (JUMP is 1.3 times bigger); at most 26% of the viewport height.
static func platform_button(vp: Vector2) -> float:
	return minf(sized(JUMP_MM, 112.0, vp), vp.y * 0.26)


## Edge of the small round buttons at the top of the screen (pause): about 12 mm.
static func top_button(vp: Vector2) -> float:
	return sized(MIN_MM, 56.0, vp)


## Translated label of the "button size" option for the command buttons ("Buttons: normal").
static func size_option_text() -> String:
	var keys: Array[String] = ["HUD_BTN_SIZE_SMALL", "HUD_BTN_SIZE_NORMAL", "HUD_BTN_SIZE_LARGE"]
	return TranslationServer.translate(keys[clampi(Options.button_size, 0, keys.size() - 1)]).to_upper()


# ---- UI scale (menus and HUD indicators) --------------------------------------------------------

## Body text should be about this tall (em, millimetres) on a real screen (medium scale: a 2000x900 phone window at 440-490 dpi reaches the MAX_UI_SCALE cap, 1.4); BODY_REF_PX is the font size the layouts use for it.
const BODY_MM := 1.8
const BODY_REF_PX := 13.0
## The scaled layout keeps at least this many logical units, so nothing that fits an 844x390 phone ever overflows.
const MIN_LOGICAL := Vector2(760.0, 360.0)
const MAX_UI_SCALE := 1.4


## Factor that makes menu/HUD text about BODY_MM tall: 1.0 on desktop (never below), more on a phone, times the player's
## button size option, capped so the layout still has MIN_LOGICAL units. Layouts are built for `logical_size(vp)`
## and drawn with `Control.scale = ui_scale(vp)` (see `scaled_root`).
static func ui_scale(vp: Vector2) -> float:
	if vp.x <= 0.0 or vp.y <= 0.0:
		return 1.0
	var s: float = maxf(1.0, mm(BODY_MM, vp) / BODY_REF_PX) * scale_option()
	var cap: float = minf(MAX_UI_SCALE, minf(vp.x / MIN_LOGICAL.x, vp.y / MIN_LOGICAL.y))
	return clampf(s, 1.0, maxf(1.0, cap))


## Size of the viewport in the units of a layout drawn with `ui_scale`.
static func logical_size(vp: Vector2) -> Vector2:
	return vp / ui_scale(vp)


## Height in logical units (see `logical_size`) of the smallest tappable item: 12 mm of the real screen, at least 40.
static func tap_min(vp: Vector2) -> float:
	return maxf(40.0, mm(MIN_MM, vp) / ui_scale(vp))


# ---- Safe area (rounded screen corners, camera cutout) ------------------------------------------

## Touch screens keep this much clear at the sides and at the top/bottom (millimetres): rounded phone corners.
const CORNER_MM := 3.0
const CORNER_MM_V := 1.5
## An OS cutout inset larger than this fraction of the window is ignored (bogus value).
const MAX_INSET_FRACTION := 0.15
## Not ZERO: replaces the OS cutout insets (left, top, right, bottom; real screen pixels) in tests and screenshot tools.
static var force_cutout: Vector4 = Vector4.ZERO


## Gap (left, top, right, bottom; viewport units) to keep clear at each edge so nothing is cut by the rounded corners or the
## camera hole: the bigger of the OS safe area (display cutout) and CORNER_MM / CORNER_MM_V. Zero when the touch UI is off.
static func safe_insets(vp: Vector2) -> Vector4:
	if not active(vp) or vp.x <= 0.0 or vp.y <= 0.0:
		return Vector4.ZERO
	var side: float = mm(CORNER_MM, vp)
	var vert: float = mm(CORNER_MM_V, vp)
	var cut: Vector4 = _cutout_px() / pixel_ratio(vp)
	return Vector4(maxf(side, cut.x), maxf(vert, cut.y), maxf(side, cut.z), maxf(vert, cut.w))


## The window's edges hidden by the display cutout, in real pixels (left, top, right, bottom).
static func _cutout_px() -> Vector4:
	if force_cutout != Vector4.ZERO:
		return force_cutout
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var pos: Vector2i = DisplayServer.window_get_position()
	var out := Vector4(safe.position.x - pos.x, safe.position.y - pos.y, pos.x + win.x - safe.end.x, pos.y + win.y - safe.end.y)
	var lim := Vector2(win) * MAX_INSET_FRACTION
	return Vector4(_inset_or_zero(out.x, lim.x), _inset_or_zero(out.y, lim.y), _inset_or_zero(out.z, lim.x), _inset_or_zero(out.w, lim.y))


static func _inset_or_zero(v: float, limit: float) -> float:
	return v if v > 0.0 and v <= limit else 0.0


## The part of the viewport clear of the corners and the cutout (see `safe_insets`), in viewport units.
static func safe_rect(vp: Vector2) -> Rect2:
	var i: Vector4 = safe_insets(vp)
	return Rect2(i.x, i.y, vp.x - i.x - i.z, vp.y - i.y - i.w)


## A transparent Control child of `host` that is `logical_size` big and scaled by `ui_scale`, so it covers the viewport
## from its top-left corner (or `rect`, in viewport units, when given), trimmed to `safe_rect`: build the screen inside it.
static func scaled_root(host: Control, vp: Vector2, rect: Rect2 = Rect2()) -> Control:
	var s: float = ui_scale(vp)
	var area: Rect2 = rect if rect.size.x > 0.0 else Rect2(Vector2.ZERO, vp)
	var safe: Rect2 = safe_rect(vp)
	if safe.size.x > 0.0 and safe.size.y > 0.0 and area.intersects(safe):
		area = area.intersection(safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = area.position
	root.scale = Vector2(s, s)
	root.size = area.size / s
	host.add_child(root)
	return root


## Makes every button below `root` at least `tap_min` tall (touch layouts only; desktop is left alone). `logical_h` is the
## height of the scaled layout: a tappable item never takes more than a seventh of it, so a phone's menu still fits.
static func fit_taps(root: Node, vp: Vector2, logical_h: float) -> void:
	if not active(vp):
		return
	var h: float = minf(tap_min(vp), logical_h * 0.14)
	_fit_taps_in(root, h)


static func _fit_taps_in(node: Node, h: float) -> void:
	for c in node.get_children():
		if c is BaseButton and (c as Control).custom_minimum_size.y < h:
			(c as Control).custom_minimum_size.y = h
		_fit_taps_in(c, h)
