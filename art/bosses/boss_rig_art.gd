## Base of the boss arts: a ThingArt that draws a BossRig (parts under assets/sprites/bosses/<id>/) and falls back to the old vector art
## while a part is missing. Subclasses build the rig in `_init` and pose + draw it in `_draw_rig`.
class_name BossRigArt
extends ThingArt

var rig: BossRig = null
var fallback: ThingArt = null
var _sample: Variant = null


func _init(p_fallback: ThingArt = null) -> void:
	fallback = p_fallback


func vector_fallback() -> ThingArt:
	return fallback


func sample_state() -> Variant:
	return _sample


func sample_extent() -> Vector2:
	return Vector2(90.0, 90.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if rig == null or not rig.is_complete():
		if fallback != null:
			fallback.draw(ci, state, ctx)
		return
	_draw_rig(ci, state, ctx)


func _draw_rig(_ci: CanvasItem, _state: Variant, _ctx: ArtContext) -> void:
	pass


## Combat ViewCtx (null-safe boss state string).
static func boss_state(ctx: ArtContext) -> String:
	return ctx.combat.boss_state if ctx.combat != null else ""


## Fighter sample for the contact sheet and the tests.
static func sample_fighter(kind: String, r: float, ai_state: String = "idle") -> Dictionary:
	return {"x": 0.0, "y": -r, "r": r, "facing": 1.0, "id": 1, "kind": kind, "ai_state": ai_state, "flying": true, "hurt_timer": 0.0}


## Red flash over the body while hurt (rig-space ellipse), `root` is the rig transform.
static func hurt_flash(ci: CanvasItem, root: Transform2D, radius: Vector2, hurt: float) -> void:
	if hurt <= 0.0:
		return
	ci.draw_set_transform_matrix(root)
	ViewUtil.fill_ellipse(ci, Vector2.ZERO, radius.x, radius.y, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Knocked-out eye: covers the painted eye with a disc of `cover` colour and draws an X, at the rig-space point `p`.
static func ko_eye(ci: CanvasItem, root: Transform2D, p: Vector2, size: float, cover: Color, line: Color) -> void:
	ci.draw_set_transform_matrix(root)
	ci.draw_circle(p, size * 1.35, cover)
	ci.draw_line(p + Vector2(-size, -size), p + Vector2(size, size), line, size * 0.5, true)
	ci.draw_line(p + Vector2(size, -size), p + Vector2(-size, size), line, size * 0.5, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
