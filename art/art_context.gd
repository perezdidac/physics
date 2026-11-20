## What an art class may read besides the state of the thing it draws: the animation clock, the wind, the night amount and
## (in the battle and in the actor views) the per-frame ViewCtx. One instance per view, refreshed every frame. Kept small on purpose.
class_name ArtContext
extends RefCounted

## Animation clock in seconds.
var t: float = 0.0
## Wind in px/s (battle) used by the swaying plants; 0 elsewhere.
var wind: float = 0.0
## Night darkness 0..1 (platformer levels); 0 = day.
var night: float = 0.0
## The battle / actor ViewCtx; null for views that have none (the contact sheet, tests).
var combat: ViewCtx = null


static var _shared: ArtContext = null


## Shared context for static art helpers that only hold a ViewCtx (refreshed on every call, re-created when the ViewCtx changes).
static func of(vctx: ViewCtx) -> ArtContext:
	if _shared == null or _shared.combat != vctx:
		_shared = ArtContext.new()
	_shared.refresh(vctx)
	return _shared


static func clear_shared() -> void:
	_shared = null


## Context for a ViewCtx-driven view (reads the clock and the wind from it).
static func from_view(vctx: ViewCtx) -> ArtContext:
	var c := ArtContext.new()
	c.refresh(vctx)
	return c


## Copies the clock and the wind of `vctx` (call once per frame before drawing).
func refresh(vctx: ViewCtx) -> void:
	combat = vctx
	t = vctx.t_now
	wind = vctx.wind


## Context for the contact sheet and the tests: a fixed time and a default ViewCtx.
static func sample(time: float = 1.0) -> ArtContext:
	var c := ArtContext.new()
	c.t = time
	c.combat = ViewCtx.new()
	c.combat.t_now = time
	return c
