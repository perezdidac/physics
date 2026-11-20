## The sunny goal (moonlight in night flights): the ring of stones at the foot is assets/sprites/platform_props/goal_base.svg; the light
## shaft, sun, rays, pool of light and motes are code (light effects). State: {goal: Rect2, view: Rect2 (visible world), moonlit: bool}.
class_name GoalArt
extends SpriteArt

## World width of the ring per unit of goal width.
const RING_W: float = 0.8
## Content width of the ring in the viewBox.
const RING_UNITS: float = 118.0


func _init() -> void:
	super("platform_props", "goal_base", 100.0, GoalVectorArt.new())
	anchor = Vector2(64.0, 96.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var g: Rect2 = state["goal"]
	if not g.grow(500.0).intersects(state["view"]):
		return
	super(ci, state, ctx)


func _box(state: Variant) -> float:
	return (state["goal"] as Rect2).size.x * RING_W * VIEWBOX / RING_UNITS


func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	var g: Rect2 = state["goal"]
	return Vector2(g.get_center().x, g.end.y)


func _modulate(state: Variant) -> Color:
	return Color(0.72, 0.8, 1.0) if ViewUtil.gb(state, "moonlit") else Color.WHITE


## Shaft, sun, rays and the wide bloom of the light on the ground (behind the ring).
func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var g: Rect2 = state["goal"]
	var t: float = ctx.t
	var c: Vector2 = g.get_center()
	var shaft_w: float = g.size.x
	var top_y: float = g.position.y - 520.0
	var glow: Color = Color(0.72, 0.84, 1.0) if ViewUtil.gb(state, "moonlit") else Color(1.0, 0.86, 0.42)
	var warm := Color(glow, 0.0)
	var warm2 := Color(glow, 0.22)
	ci.draw_polygon(PackedVector2Array([Vector2(c.x - shaft_w * 0.5, top_y), Vector2(c.x + shaft_w * 0.5, top_y), Vector2(c.x + shaft_w * 1.1, g.end.y), Vector2(c.x - shaft_w * 1.1, g.end.y)]), PackedColorArray([warm, warm, warm2, warm2]))
	var sun := Vector2(c.x, g.position.y - 70.0)
	for k in 8:
		ci.draw_circle(sun, 150.0 - float(k) * 16.0, Color(1.0, 0.88, 0.45, 0.05 + float(k) * 0.012))
	for k in 12:
		var a: float = float(k) / 12.0 * TAU + t * 0.15
		var half: float = 0.07
		var r0: float = 40.0
		var r1: float = 130.0 + 20.0 * sin(t * 1.3 + float(k))
		ci.draw_colored_polygon(PackedVector2Array([sun + Vector2(cos(a - half), sin(a - half)) * r0, sun + Vector2(cos(a), sin(a)) * r1, sun + Vector2(cos(a + half), sin(a + half)) * r0]), Color(1.0, 0.93, 0.6, 0.14))
	ci.draw_circle(sun, 34.0, Color(1.0, 0.95, 0.7, 0.35))
	ci.draw_circle(sun, 26.0, Color(1.0, 0.97, 0.78, 0.8))
	ci.draw_circle(sun, 19.0, Color(1.0, 1.0, 0.92, 0.95))
	ViewUtil.fill_ellipse(ci, Vector2(c.x, g.end.y - 2.0), shaft_w * 0.95, 14.0, Color(1.0, 0.85, 0.4, 0.3))


## A lighter glow on the ring's floor and the floating motes (over the ring).
func _overlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var g: Rect2 = state["goal"]
	var t: float = ctx.t
	var c: Vector2 = g.get_center()
	var shaft_w: float = g.size.x
	ViewUtil.fill_ellipse(ci, Vector2(c.x, g.end.y - 2.0), shaft_w * 0.55, 7.0, Color(1.0, 0.95, 0.7, 0.3))
	for k in 9:
		var fk: float = float(k)
		var mx: float = c.x + sin(t * 0.6 + fk * 1.9) * shaft_w * 0.6
		var my: float = fposmod(g.end.y - t * (12.0 + fk * 2.0) - fk * 37.0, g.size.y + 80.0) + g.position.y - 80.0
		ci.draw_circle(Vector2(mx, my), 1.6 + fmod(fk, 2.0), Color(1.0, 0.97, 0.75, 0.55))


func sample_state() -> Variant:
	return {"goal": Rect2(-30.0, -60.0, 60.0, 60.0), "view": Rect2(-400.0, -700.0, 800.0, 800.0), "moonlit": false}
