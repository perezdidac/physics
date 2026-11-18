## Small static helpers shared by the menus and HUD scenes: theme, sounds, labels, touch detection, weapon tables.
class_name UiUtil
extends RefCounted

const THEME_PATH := "res://ui/theme.tres"

## Set to true by the first touch event (replaces `body.touch-device` of the original).
static var touch_seen: bool = false
static var _theme: Theme = null


## The project theme (ui/theme.tres), cached.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
	return _theme


## Plays a sound effect through the Sound autoload when it provides `play` (the audio port may not be there yet).
static func sfx(sound_name: String) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var snd: Node = loop.root.get_node_or_null("Sound")
	if snd != null and snd.has_method("play"):
		snd.call("play", sound_name)


## Calls a method of the Sound autoload if it exists.
static func sound_call(method: String, args: Array = []) -> Variant:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var snd: Node = loop.root.get_node_or_null("Sound")
	if snd != null and snd.has_method(method):
		return snd.callv(method, args)
	return null


## True on touch layouts: first touch seen, a touchscreen, or a small window (original media query).
static func is_touch_ui(viewport_size: Vector2) -> bool:
	return touch_seen or DisplayServer.is_touchscreen_available() or viewport_size.x <= 920.0 or viewport_size.y <= 560.0


## True on a phone-sized landscape window (original `max-height: 540px`).
static func is_compact(viewport_size: Vector2) -> bool:
	return viewport_size.y <= 540.0


## Creates a Label (pass an already translated text) using a theme type variation.
static func label(text: String, variation: String = "", size: int = 0, color: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	if not variation.is_empty():
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color is Color:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Returns a copy of the theme font of `variation` with extra glyph spacing (CSS letter-spacing).
static func spaced_font(variation: String, spacing: float) -> Font:
	var base: Font = get_theme().get_font("font", variation)
	var fv: FontVariation = (base as FontVariation).duplicate()
	fv.spacing_glyph = int(round(spacing))
	return fv


## Label with CSS letter-spacing.
static func spaced_label(text: String, variation: String, size: int, color: Color, spacing: float) -> Label:
	var l: Label = label(text, variation, size, color)
	l.add_theme_font_override("font", spaced_font(variation, spacing))
	return l


## Makes `ctrl` and every descendant ignore the mouse (decorative children of buttons).
static func ignore_mouse(ctrl: Control) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in ctrl.get_children():
		if c is Control:
			ignore_mouse(c)


## Horizontal gradient texture for fade lines (transparent, colour, transparent).
static func fade_gradient(color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(color, 0.0), color, Color(color, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 4
	return tex


## Vertical gradient texture (top colour to bottom colour).
static func vertical_gradient(top: Color, bottom: Color, height: int = 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([top, bottom])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = height
	return tex


## Radial gradient texture (centre colour to edge colour) stretched over a rect.
static func radial_gradient(center: Color, edge: Color, center_pos: Vector2 = Vector2(0.5, 0.5)) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([center, edge])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = center_pos
	tex.fill_to = Vector2(center_pos.x + 0.75, center_pos.y)
	tex.width = 256
	tex.height = 256
	return tex


## Reads property `prop_name` of `obj` (sim objects, dictionaries) or returns `fallback` when the object or the property is missing.
static func prop(obj: Variant, prop_name: String, fallback: Variant = null) -> Variant:
	if obj == null:
		return fallback
	if obj is Dictionary:
		return (obj as Dictionary).get(prop_name, fallback)
	if obj is Object:
		var v: Variant = (obj as Object).get(prop_name)
		return fallback if v == null else v
	return fallback


## Toggles music: saves the Options value and tells Sound. Returns the new state.
static func toggle_music() -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var opts: Node = loop.root.get_node_or_null("Options") if loop != null else null
	if opts == null:
		return true
	opts.set("music_on", not bool(opts.get("music_on")))
	opts.call("save_options")
	sound_call("set_music", [opts.get("music_on")])
	return bool(opts.get("music_on"))


## Translates `key` and fills its `%s`/`%d` placeholders with `args`. While a key has no translation (it comes back unchanged
## and has no placeholders) the values are appended so nothing breaks.
static func fmt(key: String, args: Array) -> String:
	var text: String = TranslationServer.translate(key)
	if text.contains("%"):
		return text % args
	return "%s %s" % [text, " ".join(args.map(func(a: Variant) -> String: return str(a)))]
