## What the view reads of a La Processó (CONVOY) level, in one place: the sim fields are looked up here by name with safe defaults, so the drawing
## code only sees the ViewCtx. Contract (docs/procession_contracts.md): SimFighter.is_leader, SimFighter.lost, an optional place in the file
## (`line_index`, 0 = leader), sim.march_left / march_budget, level or sim `goal_x` and `spores`.
class_name ConvoyInfo
extends RefCounted

## Win rules whose levels draw the goal zone and the march HUD.
const RULES: Array[String] = ["CONVOY", "BOSS_OR_GOAL"]
## Phase lag of the walk cycle between two neighbours in the file: the wave of the line.
const WAVE_LAG: float = 1.25


## Fills the convoy fields of `ctx` from the sim (everything stays at the defaults outside a CONVOY level).
static func read(ctx: ViewCtx, sim: Object) -> void:
	var lv: Variant = ViewUtil.g(sim, "level")
	ctx.leader = null
	ctx.line = []
	ctx.spores = []
	ctx.boar_intents = []
	ctx.convoy = false
	ctx.goal_x = -1.0
	ctx.march_left = 0.0
	ctx.march_budget = 0.0
	if lv == null:
		return
	for f in ctx.fighters:
		if ViewUtil.gb(f, "is_leader") and ViewUtil.gb(f, "alive"):
			ctx.leader = f
	ctx.convoy = ctx.leader != null or RULES.has(ViewUtil.gs(lv, "win_rule"))
	if not ctx.convoy:
		return
	ctx.goal_x = ViewUtil.gf(sim, "goal_x", ViewUtil.gf(lv, "goal_x", -1.0))
	ctx.goal_half = ViewUtil.gf(sim, "goal_radius", ViewUtil.gf(lv, "goal_radius", 80.0))
	ctx.goal_y = ViewUtil.gf(sim, "goal_y")
	for it in ViewUtil.g(sim, "boar_intents", []):
		if it is Dictionary:
			ctx.boar_intents.append(it)
	ctx.march_budget = ViewUtil.gf(sim, "march_budget", ViewUtil.gf(lv, "march_budget", 0.0))
	ctx.march_left = clampf(ViewUtil.gf(sim, "march_left", ctx.march_budget), 0.0, maxf(ctx.march_budget, 0.0))
	var sp: Variant = ViewUtil.g(sim, "spores", ViewUtil.g(lv, "spores", []))
	for r in sp:
		if r is Rect2:
			ctx.spores.append(r)
	ctx.line = line_of(ctx.fighters)


## The living members of the player's file, leader first, then by their place in it (the order of the squad when the sim gives none).
static func line_of(fighters: Array) -> Array:
	var out: Array = []
	for f in fighters:
		var kind: String = ViewUtil.gs(f, "kind", "CATERPILLAR")
		if ViewUtil.gi(f, "team") == 0 and ViewUtil.gb(f, "alive") and not ViewUtil.gb(f, "drowning") and (kind == "CATERPILLAR" or kind.begins_with("LARVA")):
			out.append(f)
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return place(a) < place(b))
	return out


## Place in the file: 0 for the leader, then 1, 2... (`line_index` or the squad order).
static func place(f: Variant) -> int:
	if ViewUtil.gb(f, "is_leader"):
		return 0
	var idx: int = ViewUtil.gi(f, "line_index", -1)
	if idx >= 0:
		return idx
	return 1000 + ViewUtil.gi(f, "member_idx") if ViewUtil.gb(f, "lost") else 1 + ViewUtil.gi(f, "member_idx")


## Walk phase of a fighter: the sim animates the followers while they catch up; the view lags each one by its place so the file ripples like one
## animal (a lost one just fidgets).
static func walk_of(ctx: ViewCtx, f: Variant) -> float:
	var own: float = ViewUtil.gf(f, "walk_cycle")
	if not ctx.convoy or ViewUtil.gi(f, "team") != 0 or ViewUtil.gb(f, "is_leader"):
		return own
	if ViewUtil.gb(f, "lost"):
		return ctx.t_now * 9.0
	return own - float(place(f)) * WAVE_LAG


## Followers still in the file (alive and not lost) and the squad's followers at the start (alive or not): the "Seguidors N/M" of the HUD.
static func follower_counts(fighters: Array) -> Vector2i:
	var kept: int = 0
	var total: int = 0
	for f in fighters:
		if ViewUtil.gi(f, "team") != 0 or ViewUtil.gb(f, "is_leader"):
			continue
		total += 1
		if ViewUtil.gb(f, "alive") and not ViewUtil.gb(f, "drowning") and not ViewUtil.gb(f, "lost"):
			kept += 1
	return Vector2i(kept, total)


## True when the fighter stands inside one of the fungus clouds (its turn starts with the spore pulse).
static func in_spores(ctx: ViewCtx, f: Variant) -> bool:
	var p: Vector2 = ViewUtil.pos(f)
	for r in ctx.spores:
		if r.has_point(p):
			return true
	return false
