## Art of a boss by the art key of its BossDef: the tachinid fly, the great tit (the bird art, bigger), the Capatàs of the forestry brigade, the cuckoo or a plain blob for a boss
## without art. Resting / perched bosses (BossDef.vulnerable_states) get a golden pulsing halo.
class_name BossArt
extends RefCounted

## Registry ids this view draws through (checked by the registry test; "boss:" is the plain-blob default).
const ART_KINDS: Array[String] = ["boss:"]


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	if ctx.boss_vulnerable:
		_halo(ci, f, ctx)
	ArtRegistry.draw("boss:" + ViewUtil.gs(ctx.boss_def, "art"), ci, f, ArtContext.of(ctx))


## Pulsing golden glow around the boss while it takes full damage.
static func _halo(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var r: float = ViewUtil.gf(f, "r", 16.0)
	var pulse: float = 0.5 + 0.5 * sin(ctx.t_now * 6.0)
	var c: Vector2 = ViewUtil.pos(f)
	ViewUtil.radial(ci, c, r * 0.6, r * (2.3 + pulse * 0.5), [[0.0, Color(1.0, 0.86, 0.35, 0.75)], [0.5, Color(1.0, 0.7, 0.2, 0.3)], [1.0, Color(1.0, 0.6, 0.1, 0.0)]], 0.55 + pulse * 0.4, "boss_halo")


## A boss without art of its own: a round dark body with angry eyes.
static func draw_blob(ci: CanvasItem, f: Variant) -> void:
	var r: float = ViewUtil.gf(f, "r", 16.0)
	var c: Vector2 = ViewUtil.pos(f)
	ViewUtil.circle_fs(ci, c, r, ViewColors.h("#3b3340"), ViewColors.h("#0d0e12"), 2.0)
	var dir: float = ViewUtil.gf(f, "facing", 1.0)
	for k in 2:
		var e: Vector2 = c + Vector2((0.25 + 0.38 * float(k)) * r * dir, -r * 0.2)
		ci.draw_circle(e, r * 0.2, Color.WHITE)
		ci.draw_circle(e + Vector2(dir * r * 0.04, 0.0), r * 0.09, ViewColors.h("#d8252b"))
	ci.draw_line(c + Vector2(0.1 * r * dir, -r * 0.5), c + Vector2(0.8 * r * dir, -r * 0.38), ViewColors.h("#0d0e12"), 2.0, true)
