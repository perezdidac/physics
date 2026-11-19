## CutoutRig with a global tint (hit flash, drowning, hidden alpha), per-part visibility and optional per-part tint.
## Parts live in assets/sprites/creatures/<id>/<part>.svg like every CutoutRig.
class_name CreatureRig
extends CutoutRig

## Multiplied over every part.
var modulate: Color = Color.WHITE
var _hidden: Dictionary = {}
var _tints: Dictionary = {}
var _source: Dictionary = {}


func _init(p_id: String, p_box: float) -> void:
	super("creatures", p_id, p_box)


## Adds a second (third...) instance of the SVG `source`: a part named `part` that draws <source>.svg (segments of a larva).
func add_instance(part: String, source: String, pivot: Vector2 = Vector2(64.0, 64.0), rest: Vector2 = Vector2.ZERO) -> void:
	_source[part] = source
	add_part(part, pivot, rest)


func part_path(part: String) -> String:
	return super(_source.get(part, part))


func set_visible_part(part: String, vis: bool) -> void:
	_hidden[part] = not vis


func set_part_tint(part: String, col: Color) -> void:
	_tints[part] = col


## Resets the poses of every part to rest (call before posing a frame so a part nobody sets does not keep an old pose).
func reset_poses() -> void:
	for part in _names:
		_pose[part] = [0.0, Vector2.ZERO, Vector2.ONE]
		_hidden.erase(part)
		_tints.erase(part)


func draw(ci: CanvasItem, root: Transform2D, anchor: Vector2 = SpriteArt.DEFAULT_ANCHOR) -> void:
	var k: float = box / SpriteArt.VIEWBOX
	for part in _names:
		if _hidden.get(part, false):
			continue
		var tex: Texture2D = part_texture(part)
		if tex == null:
			continue
		var pivot: Vector2 = _pivot[part]
		var pose: Array = _pose[part]
		var local := Transform2D(0.0, Vector2.ONE, 0.0, (pivot - anchor + (_rest[part] as Vector2)) * k) * Transform2D(float(pose[0]), pose[2] as Vector2, 0.0, (pose[1] as Vector2) * k)
		ci.draw_set_transform_matrix(root * local)
		var col: Color = modulate
		if _tints.has(part):
			col = col * (_tints[part] as Color)
		ci.draw_texture_rect(tex, Rect2(-pivot * k, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * k), false, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
