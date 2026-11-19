## The weapon in the hands of the active fighter: assets/sprites/weapons/held_<id>.svg, drawn in the fighter's aim frame
## (+x = aim direction, origin = the grip, already lifted 3 px like the vector art). Code-drawn moving bits: the fuet whip,
## the spoon wobble, the drill jitter. A weapon without a sprite falls back to WeaponArt.
## State: {root: Transform2D of the fighter, f: the fighter}.
class_name WeaponHeldArt
extends ThingArt

## World size of the 128-unit viewBox and the grip point inside it (the SVGs use 3.2 units per world px).
const BOX: float = 40.0
const GRIP := Vector2(34.0, 64.0)

static var _rng := RandomNumberGenerator.new()

var _sprites: Dictionary = {}


func _sprite(wid: String) -> SpriteArt:
	if not _sprites.has(wid):
		_sprites[wid] = SpriteArt.new("weapons", "held_" + wid.to_lower(), BOX)
	return _sprites[wid]


func vector_fallback() -> ThingArt:
	return null


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var vc: ViewCtx = ctx.combat
	if vc == null:
		return
	var f: Variant = state["f"]
	var wid: String = vc.weapon_id
	var tex: Texture2D = _sprite(wid).texture()
	if tex == null:
		WeaponArt.draw_held(ci, state["root"], f, vc)
		return
	var swing_t: float = ViewUtil.gf(f, "bat_swing_timer")
	var swing: float = sin(swing_t * 18.0) * 1.8 if swing_t > 0.0 else 0.0
	var base: Transform2D = (state["root"] as Transform2D) * Transform2D(vc.aim_angle + swing, Vector2.ONE, 0.0, Vector2(0, -3))
	var local := Transform2D.IDENTITY
	match wid:
		"CULLERA":
			if ViewUtil.gf(f, "spoon_timer") > 0.0:
				local = Transform2D(sin(vc.t_now * 28.0) * 0.28, Vector2.ONE, 0.0, Vector2.ZERO)
		"BARRINA":
			if ViewUtil.gf(f, "drill_timer") > 0.0:
				local = Transform2D(0.0, Vector2.ONE, 0.0, Vector2((_rng.randf() - 0.5) * 3.0, 0))
	ci.draw_set_transform_matrix(base * local)
	var k: float = BOX / SpriteArt.VIEWBOX
	ci.draw_texture_rect(tex, Rect2(-GRIP * k, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * k), false)
	if wid == "FUET":
		_whip(ci, swing_t)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The bending whip of the fuet (the handle is the sprite).
func _whip(ci: CanvasItem, swing_t: float) -> void:
	var bend: float = sin(swing_t * 26.0) * 7.0 if swing_t > 0.0 else -2.5
	ci.draw_polyline(ViewUtil.quad_pts(Vector2(4, 1), Vector2(15, bend), Vector2(28, bend * 0.6), 10), ViewColors.h("#7a1f2d"), 5.4, true)
	ViewUtil.dashed(ci, ViewUtil.quad_pts(Vector2(4, 1), Vector2(15, bend), Vector2(27, bend * 0.6), 14), 2.8, 2.2, ViewColors.h("#f4eee1"), 4.2)
	ci.draw_line(Vector2(28, bend * 0.6), Vector2(32, bend * 0.6 - 3), ViewColors.h("#d9b372"), 1.4, true)
	ci.draw_line(Vector2(28, bend * 0.6), Vector2(32, bend * 0.6 + 2.5), ViewColors.h("#d9b372"), 1.4, true)
