## Mechanism for sprite creatures: a set of named SVG parts (assets/sprites/<group>/<id>/<part>.svg, 128-unit viewBox like every
## sprite) that the creature's own code animates. Each part has a pivot (the viewBox point it rotates around), a rest offset
## in rig space and a draw order; per frame the creature sets a local transform (rotation, scale, offset) per part by name.
## The rig origin (0, 0) is the creature's ground anchor; `box` is the world size of one 128-unit viewBox.
##
##   var rig := CutoutRig.new("creatures", "ant", 40.0)
##   rig.add_part("body", Vector2(64, 64))
##   rig.add_part("leg_fl", Vector2(60, 70), Vector2(-6, 2))     # pivot in the part SVG, rest offset in rig units (viewBox scale)
##   ...
##   rig.set_pose("leg_fl", swing_angle)                          # every frame
##   if rig.is_complete(): rig.draw(ci, Transform2D(0.0, Vector2(facing, 1), 0.0, pos))
##
## Parts missing on disk make `is_complete()` false so the creature keeps drawing its vector art (same fallback rule as SpriteArt).
class_name CutoutRig
extends RefCounted

var group: String = ""
var id: String = ""
var box: float = 32.0
var _names: Array[String] = []
var _pivot: Dictionary = {}
var _rest: Dictionary = {}
var _pose: Dictionary = {}
var _textures: Dictionary = {}


func _init(p_group: String, p_id: String, p_box: float) -> void:
	group = p_group
	id = p_id
	box = p_box


## Adds a part drawn after the previously added ones. `pivot` is the point of the part SVG (viewBox units) it rotates and scales
## around; `rest` shifts the part from where it sits in the shared 128-unit drawing (viewBox units, normally zero).
func add_part(part: String, pivot: Vector2 = Vector2(64.0, 64.0), rest: Vector2 = Vector2.ZERO) -> void:
	_names.append(part)
	_pivot[part] = pivot
	_rest[part] = rest
	_pose[part] = [0.0, Vector2.ZERO, Vector2.ONE]


func part_path(part: String) -> String:
	return "%s%s/%s/%s.svg" % [SpriteArt.ROOT, group, id, part]


func part_texture(part: String) -> Texture2D:
	if not _textures.has(part):
		var p: String = part_path(part)
		_textures[part] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _textures[part]


## True when every part has its SVG.
func is_complete() -> bool:
	if _names.is_empty():
		return false
	for part in _names:
		if part_texture(part) == null:
			return false
	return true


## Sets the animation of a part: rotation (rad) and scale around its pivot plus an extra offset (viewBox units).
func set_pose(part: String, rotation_rad: float, offset: Vector2 = Vector2.ZERO, part_scale: Vector2 = Vector2.ONE) -> void:
	_pose[part] = [rotation_rad, offset, part_scale]


## Draws all parts under `root` (world transform of the rig origin, e.g. position and facing flip).
func draw(ci: CanvasItem, root: Transform2D, anchor: Vector2 = SpriteArt.DEFAULT_ANCHOR) -> void:
	var k: float = box / SpriteArt.VIEWBOX
	for part in _names:
		var tex: Texture2D = part_texture(part)
		if tex == null:
			continue
		var pivot: Vector2 = _pivot[part]
		# part-local: move pivot to the origin, pose around it, then place relative to the rig anchor
		var pose: Array = _pose[part]
		var local := Transform2D(0.0, Vector2.ONE, 0.0, (pivot - anchor + (_rest[part] as Vector2)) * k) * Transform2D(float(pose[0]), pose[2] as Vector2, 0.0, (pose[1] as Vector2) * k)
		ci.draw_set_transform_matrix(root * local)
		ci.draw_texture_rect(tex, Rect2(-pivot * k, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * k), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
