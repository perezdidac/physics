## A sap drop (nutrient pickup): the drop is assets/sprites/platform_props/nutrient.svg, the bobbing, glow and twinkle are code.
## State: {i: index, p: world position}.
class_name NutrientArt
extends SpriteArt

## The drop is 1.4x the old teardrop (about 19 x 25 px).
const BOX: float = 34.0


func _init() -> void:
	super("platform_props", "nutrient", BOX, NutrientVectorArt.new())
	anchor = Vector2(64.0, 64.0)


static func _bob(state: Variant, ctx: ArtContext) -> float:
	return sin(ctx.t * 2.3 + float(ViewUtil.gi(state, "i")) * 1.7) * 3.0


func _origin(state: Variant, ctx: ArtContext) -> Vector2:
	return (state["p"] as Vector2) + Vector2(0.0, _bob(state, ctx))


func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var c: Vector2 = _origin(state, ctx)
	var pulse: float = 0.5 + 0.5 * sin(ctx.t * 3.0 + float(ViewUtil.gi(state, "i")))
	for k in 4:
		ci.draw_circle(c, (22.0 - float(k) * 4.5) * 1.4, Color(1.0, 0.72, 0.2, 0.07 + 0.03 * pulse + float(k) * 0.03))


func _overlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var c: Vector2 = _origin(state, ctx)
	var i: int = ViewUtil.gi(state, "i")
	var tw: float = maxf(0.0, sin(ctx.t * 2.0 + float(i) * 2.1))
	if tw > 0.0:
		var s: float = (4.0 + 6.0 * tw) * 1.4
		var sp: Vector2 = c + Vector2(11.0, -14.0)
		var col := Color(1.0, 0.98, 0.8, tw)
		ci.draw_line(sp - Vector2(s, 0.0), sp + Vector2(s, 0.0), col, 1.3, true)
		ci.draw_line(sp - Vector2(0.0, s), sp + Vector2(0.0, s), col, 1.3, true)


func sample_state() -> Variant:
	return {"i": 0, "p": Vector2(0.0, -14.0)}
