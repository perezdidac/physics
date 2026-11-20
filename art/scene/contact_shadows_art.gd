## Sun-cast contact shadows under the fighters, barrels, crates, mines, mushrooms, caganers and tombstones (drawGroundContactShadows).
## State: the sim. Reads the terrain, the map id and the water line from the ViewCtx.
class_name ContactShadowsArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, actx: ArtContext) -> void:
	var sim: Object = state
	var ctx: ViewCtx = actx.combat
	if ctx == null:
		return
	var terrain: Object = ctx.terrain
	var sun_shift: float = -3.5 if (ctx.map_id == "MONTSERRAT" or ctx.map_id == "CASTELLFOLLIT") else (3.5 if ctx.map_id == "CADAQUES" else 1.0)
	for f in ctx.fighters:
		if not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		var shade_w: float = 12.5 * (LarvaArt.scale_of(f) if ViewUtil.gs(f, "kind").begins_with("LARVA") else 1.0)
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + ViewUtil.gf(f, "r", 12.0), shade_w, 3.8, 0.44)
		var segs: Variant = ViewUtil.g(f, "segs", []) if ViewUtil.gs(f, "kind", "CATERPILLAR") == "CATERPILLAR" else []
		var i: int = 0
		while i < segs.size():
			_shadow(ci, terrain, ctx, sun_shift, ViewUtil.pos(segs[i]).x, ViewUtil.pos(segs[i]).y + 5.0, 7.5 - float(i) * 0.5, 2.5, 0.32)
			i += 2
	for b in ViewUtil.g(sim, "barrels", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(b, "x"), ViewUtil.gf(b, "y") + ViewUtil.gf(b, "r", 14.0), 14.0, 4.2, 0.48)
	for c in ViewUtil.g(sim, "crates", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(c, "x"), ViewUtil.gf(c, "y") + 10.0, 12.0, 3.6, 0.45)
	for m in ViewUtil.g(sim, "mines", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(m, "x"), ViewUtil.gf(m, "y") + 4.0, 9.0, 2.8, 0.42)
	for rv in ViewUtil.g(sim, "rovellons", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(rv, "x"), ViewUtil.gf(rv, "y"), ViewUtil.gf(rv, "r", 18.0) * 0.9, 3.8, 0.44)
	for cg in ViewUtil.g(sim, "caganers", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(cg, "x"), ViewUtil.gf(cg, "y") + 7.0, 10.0, 3.2, 0.44)
	for tb in ViewUtil.g(sim, "tombstones", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(tb, "x"), ViewUtil.gf(tb, "y") + 10.0, 11.0, 3.4, 0.46)


func _shadow(ci: CanvasItem, terrain: Object, ctx: ViewCtx, sun_shift: float, x: float, y: float, rx: float, ry: float, alpha: float) -> void:
	if terrain == null or not terrain.has_method("find_surface_y"):
		return
	var sy: float = float(terrain.call("find_surface_y", x, y - 4.0))
	var dist: float = sy - y
	if dist < -6.0 or dist > 54.0 or sy >= ctx.water_y:
		return
	var falloff: float = clampf(1.0 - maxf(0.0, dist) / 54.0, 0.15, 1.0)
	ViewUtil.fill_ellipse(ci, Vector2(x + sun_shift * (0.4 + (1.0 - falloff) * 0.8), sy + 1.0), rx * (0.7 + falloff * 0.35), ry, Color(ViewColors.SHADOW, alpha * falloff), 0.0)
