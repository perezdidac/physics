## One Catalan theatre (see data/maps/). Colours are Color; the sim converts them to 0..255 values.
class_name MapDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var subtitle_key: String = ""
@export var badge_key: String = ""
## Key for ArtCatalog.background().
@export var background_key: String = ""
@export var weather: String = ""
@export var slide_friction: float = 0.965
@export var sky: PackedColorArray = PackedColorArray()
@export var water_top: Color = Color.WHITE
@export var water_deep: Color = Color.WHITE
@export var turf_col: Color = Color.WHITE
@export var soil_col: Color = Color.WHITE
@export var rock_col: Color = Color.WHITE
@export var tree_style: String = ""
@export var preferred_texture: String = ""


## Colour as the JS [r, g, b] triple (0..255).
static func rgb255(c: Color) -> Vector3:
	return Vector3(roundf(c.r * 255.0), roundf(c.g * 255.0), roundf(c.b * 255.0))
