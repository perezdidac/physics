## (Vector fallback of the sprite art.) A checkpoint flag on its pole; lit once reached. State: {i: index, p: foot position, lit: bool}.
class_name CheckpointVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var i: int = ViewUtil.gi(state, "i")
	var p: Vector2 = state["p"]
	var lit: bool = ViewUtil.gb(state, "lit")
	var t: float = ctx.t
	var base := p
	var tip := Vector2(p.x, p.y - 58.0)
	ci.draw_line(base, tip, ViewColors.h("#5a3f22"), 3.5, true)
	ci.draw_line(base + Vector2(1.0, 0.0), tip + Vector2(1.0, 0.0), Color(ViewColors.h("#a47c4a"), 0.7), 1.2, true)
	var flag_col: Color = ViewColors.h("#ffd04a") if lit else ViewColors.h("#8f8272")
	var wave: float = sin(t * 4.0 + float(i)) * (3.0 if lit else 0.6)
	var flag := PackedVector2Array([tip + Vector2(2.0, 2.0), tip + Vector2(24.0, 8.0 + wave), tip + Vector2(2.0, 18.0)])
	if lit:
		for k in 4:
			ci.draw_circle(tip + Vector2(12.0, 10.0), 34.0 - float(k) * 7.0, Color(1.0, 0.85, 0.3, 0.06 + float(k) * 0.03))
	ci.draw_colored_polygon(flag, flag_col)
	ci.draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), ViewColors.h("#7a5410") if lit else ViewColors.h("#5b5145"), 1.3, true)
	ci.draw_circle(tip, 3.0, ViewColors.h("#fff0b0") if lit else ViewColors.h("#a99c88"))


func sample_state() -> Variant:
	return {"i": 0, "p": Vector2(-10.0, 0.0), "lit": true}
