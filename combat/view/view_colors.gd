## View-only colours (battle rendering). Values copied from reference/js/renderer.js; the shared UI palette lives in core/palette.gd.
class_name ViewColors
extends RefCounted

const TEAM_0: Color = Color("#f5b945")
const TEAM_1: Color = Color("#ea5648")
const DORSAL_0: Color = Color("#e87a24")
const DORSAL_1: Color = Color("#d93b2b")
const BODY_DEFAULT: Array[Color] = [Color("#3a3f4d"), Color("#22252e"), Color("#111318")]
const BRISTLE: Color = Color(0.9608, 0.9255, 0.8431, 0.82)
const BRISTLE_URTICATING: Color = Color("#d88aff")
const PROLEG: Color = Color("#d98a4e")
const OUTLINE_DARK: Color = Color("#0d0e12")
const THORAX: Color = Color("#252934")
const NAME_PILL: Color = Color(0.0431, 0.0549, 0.0863, 0.84)
const NAME_PILL_BORDER: Color = Color(0.9412, 0.7647, 0.4314, 0.38)
const NAME_TEXT: Color = Color("#fff8eb")
const BAR_FRAME: Color = Color(0.0, 0.0, 0.0, 0.72)
const FUEL_BAR: Color = Color("#5ad2f4")
const SPEECH_BG: Color = Color(0.0588, 0.0706, 0.098, 0.92)
const SPEECH_BORDER: Color = Color("#f6cf77")
const SPEECH_TEXT: Color = Color("#fff5df")
const WATER_BACK: Color = Color(0.0706, 0.149, 0.2039, 0.72)
const SHADOW: Color = Color(0.0235, 0.0314, 0.0549, 1.0)
const WARM_YELLOW: Color = Color("#ffd966")
const AIM_CROSS: Color = Color("#ff6b5b")
const AIM_LABEL: Color = Color("#ffe082")
const TRAIL_HOLY: Color = Color(1.0, 0.8706, 0.451)
const TRAIL_URTICARIA: Color = Color(0.847, 0.5412, 1.0)
const TRAIL_BAZOOKA: Color = Color(1.0, 0.647, 0.2941)
const TRAIL_DEFAULT: Color = Color(0.9608, 0.9333, 0.8627)
const VIGNETTE_EDGE: Color = Color(0.0196, 0.0235, 0.0353, 0.58)

## Parse cache for css-like strings.
static var _cache: Dictionary = {}


## "#rrggbb" (cached) shortcut used by the procedural art code.
static func h(hex: String) -> Color:
	return ArtKit.hex(hex)


## Colour of a team (0 / 1).
static func team(team_idx: int) -> Color:
	return TEAM_0 if team_idx == 0 else TEAM_1


## Accepts a Color, "#hex", "rgba(r, g, b, a)", "rgb(...)" or a bare "r, g, b" string and returns a Color.
static func parse(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String:
		var s: String = (v as String).strip_edges()
		if s.begins_with("#"):
			return h(s)
		if _cache.has(s):
			return _cache[s]
		var inner: String = s
		var open: int = s.find("(")
		if open >= 0:
			inner = s.substr(open + 1, s.length() - open - 2)
		var parts: PackedStringArray = inner.split(",")
		if parts.size() >= 3:
			var a: float = 1.0
			if parts.size() >= 4:
				a = parts[3].to_float()
			var c := Color(parts[0].to_float() / 255.0, parts[1].to_float() / 255.0, parts[2].to_float() / 255.0, a)
			_cache[s] = c
			return c
	return fallback
