## Projectiles in flight: trail (code), body sprite assets/sprites/weapons/proj_<kind>.svg, then the code-drawn bits (rocket and
## urticaria flames, the dynamite spark, the fuse number, the holy halo). Falls back to WeaponArt per kind.
## State: the sim projectile (x, y, vx, vy, ang, type, r, has_fuse, fuse, is_fuet_slice, trail).
class_name WeaponProjectileArt
extends ThingArt

## 4 viewBox units per world px; the sprite is centred on the viewBox.
const BOX: float = 32.0
const CENTRE := Vector2(64.0, 64.0)

static var _rng := RandomNumberGenerator.new()

var _sprites: Dictionary = {}


func _sprite(kind: String) -> SpriteArt:
	if not _sprites.has(kind):
		_sprites[kind] = SpriteArt.new("weapons", "proj_" + kind, BOX)
	return _sprites[kind]


func vector_fallback() -> ThingArt:
	return null


static func sprite_kind(p: Variant) -> String:
	var ptype: String = ViewUtil.gs(p, "type")
	if ptype == "CARQUINYOLI" and ViewUtil.gb(p, "is_fuet_slice"):
		return "fuet_slice"
	return ptype.to_lower()


func draw(ci: CanvasItem, p: Variant, ctx: ArtContext) -> void:
	var vc: ViewCtx = ctx.combat
	if vc == null:
		return
	var ptype: String = ViewUtil.gs(p, "type")
	var tex: Texture2D = _sprite(sprite_kind(p)).texture()
	if tex == null:
		WeaponArt.draw_projectile(ci, p, vc)
		return
	WeaponArt.draw_trail(ci, p)
	var t: float = vc.t_now
	var at := Vector2(ViewUtil.gf(p, "x"), ViewUtil.gf(p, "y"))
	var ang: float = ViewUtil.gf(p, "ang")
	var rot: float = ang
	var scale: float = 1.0
	match ptype:
		"CARQUINYOLI":
			rot = ang + t * 14.0
		"BAZOOKA", "BOMBLER", "URTICARIA":
			rot = atan2(ViewUtil.gf(p, "vy"), ViewUtil.gf(p, "vx"))
		"GRENADE":
			scale = ViewUtil.gf(p, "r", 6.0) / 6.0
		"DYNAMITE":
			rot = 0.0
	var k: float = BOX / SpriteArt.VIEWBOX * scale
	ci.draw_set_transform_matrix(Transform2D(rot, Vector2.ONE, 0.0, at))
	if ptype == "HOLY":
		ViewUtil.radial(ci, Vector2.ZERO, 2.0, 19.0, [[0.0, Color(1.0, 0.9216, 0.5686, 0.78)], [1.0, Color(1.0, 0.7843, 0.2941, 0.0)]], 1.0, "holy_halo")
	ci.draw_texture_rect(tex, Rect2(-CENTRE * k, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * k), false)
	if ptype == "BAZOOKA":
		ArtKit.poly(ci, PackedVector2Array([Vector2(-9, -2.5), Vector2(-17.0 - _rng.randf() * 6.0, 0), Vector2(-9, 2.5)]), ViewColors.h("#ff9b3b"), Color(0, 0, 0, 0), 0.0)
	elif ptype == "URTICARIA":
		ArtKit.poly(ci, PackedVector2Array([Vector2(-7, -2), Vector2(-14.0 - _rng.randf() * 5.0, 0), Vector2(-7, 2)]), ViewColors.h("#d88aff"), Color(0, 0, 0, 0), 0.0)
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, at))
	if ptype == "DYNAMITE":
		ci.draw_circle(Vector2(-2, -9), 3.2, ViewColors.h("#ffee77") if sin(t * 35.0) > 0.0 else ViewColors.h("#ff6622"))
	if ViewUtil.gb(p, "has_fuse") and (ptype == "GRENADE" or ptype == "CLUSTER" or ptype == "HOLY" or ptype == "DYNAMITE"):
		var y: float = -15.0 if ptype == "DYNAMITE" else -14.0
		var col: Color = ViewColors.h("#ffe57f") if ptype == "HOLY" else (ViewColors.h("#ffeb99") if ptype == "DYNAMITE" else Color.WHITE)
		ViewUtil.text(ci, str(int(ceil(ViewUtil.gf(p, "fuse")))), Vector2(0, y), 12, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
