## A ThingArt that draws a hand-authored SVG sprite (assets/sprites/<group>/<id>.svg, 128x128 viewBox) and falls back to a vector
## ThingArt when the file is missing, so the two are interchangeable (Liskov): a view never knows which one it got.
## Placement: the sprite's `anchor` (viewBox units, default bottom-centre of the object at (64, 116)) lands on the origin the
## subclass computes from the state; `box` is the world size of the whole 128-unit viewBox. Template-method hooks (_origin, _box,
## _rotation, _flip, _modulate, _underlay, _overlay) let one small subclass per kind adapt the sprite to its sim state; the
## code-drawn extras (glows, crosses, parachutes) live in the hooks and only run when the sprite is used.
## Texture loading: textures are imported by Godot with svg/scale = 2.0 (256 px for the 128-unit box, see docs/art_contracts.md).
class_name SpriteArt
extends ThingArt

const ROOT := "res://assets/sprites/"
const VIEWBOX: float = 128.0
const DEFAULT_ANCHOR := Vector2(64.0, 116.0)

static var _textures: Dictionary = {}

var group: String = ""
var id: String = ""
## World size (px) of the whole 128x128 viewBox.
var box: float = 32.0
## Ground point of the object inside the viewBox (viewBox units).
var anchor: Vector2 = DEFAULT_ANCHOR
## Tint multiplied over the sprite (white = unchanged).
var tint: Color = Color.WHITE
## The vector art used while the SVG file does not exist.
var fallback: ThingArt = null
var _sample: Variant = null


func _init(p_group: String, p_id: String, p_box: float, p_fallback: ThingArt = null) -> void:
	group = p_group
	id = p_id
	box = p_box
	fallback = p_fallback


## res:// path of the sprite file.
func path() -> String:
	return "%s%s/%s.svg" % [ROOT, group, id]


## The imported texture, or null when the file does not exist (cached either way).
func texture() -> Texture2D:
	var p: String = path()
	if not _textures.has(p):
		_textures[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _textures[p]


func has_sprite() -> bool:
	return texture() != null


## Forgets cached textures (tests).
static func clear_cache() -> void:
	_textures.clear()


func vector_fallback() -> ThingArt:
	return fallback


func sample_state() -> Variant:
	if _sample != null:
		return _sample
	return fallback.sample_state() if fallback != null else null


## Overrides the sample state (subclasses set it in _init).
func set_sample(state: Variant) -> void:
	_sample = state


func sample_extent() -> Vector2:
	return fallback.sample_extent() if fallback != null else Vector2(box, box)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var tex: Texture2D = texture()
	if tex == null:
		if fallback != null:
			fallback.draw(ci, state, ctx)
		return
	_underlay(ci, state, ctx)
	var k: float = _box(state) / VIEWBOX
	var flip: float = -1.0 if _flip(state) else 1.0
	ci.draw_set_transform_matrix(Transform2D(_rotation(state, ctx), Vector2(flip, 1.0), 0.0, _origin(state, ctx)))
	ci.draw_texture_rect(tex, Rect2(-anchor * k, Vector2(VIEWBOX, VIEWBOX) * k), false, _modulate(state))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_overlay(ci, state, ctx)


## World point the anchor lands on.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state)


## World size of the 128-unit viewBox for this instance.
func _box(_state: Variant) -> float:
	return box


func _rotation(_state: Variant, _ctx: ArtContext) -> float:
	return 0.0


func _flip(_state: Variant) -> bool:
	return false


func _modulate(_state: Variant) -> Color:
	return tint


## Code-drawn extras behind the sprite (glows).
func _underlay(_ci: CanvasItem, _state: Variant, _ctx: ArtContext) -> void:
	pass


## Code-drawn extras over the sprite (medkit cross, blink lights).
func _overlay(_ci: CanvasItem, _state: Variant, _ctx: ArtContext) -> void:
	pass
