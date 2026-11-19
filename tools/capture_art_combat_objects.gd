## Contact sheets of the combat-object sprites at 3x zoom with live-ish states (flora variants, nest damage states, anthill, tufts...).
##   godot --path . res://tools/CaptureArtCombatObjects.tscn   -> /tmp/claude-1000/sheet_combat_objects_{a,b}.png
extends Node2D

var _page: int = 0
var _frames: int = 0
var _ctx := ArtContext.new()
var _vctx := ViewCtx.new()
var _fx := NestFx.new()


func _ready() -> void:
	get_window().size = Vector2i(1500, 900)
	_ctx.t = 1.3
	_ctx.wind = 20.0
	_vctx.t_now = 1.3
	_ctx.combat = _vctx
	RenderingServer.set_default_clear_color(Color("#3a4a50"))


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 3:
		queue_redraw()
	if _frames == 6:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-1000/sheet_combat_objects_%s.png" % ("a" if _page == 0 else "b"))
		if _page == 0:
			_page = 1
			_frames = 0
		else:
			get_tree().quit()


## Draws `kind` with its origin at screen point `p` (the node is scaled, so the state is offset in world units).
func _put(kind: String, p: Vector2, state: Variant) -> void:
	var w: Vector2 = p / scale.x
	var st: Variant = state
	if st is Vector2:
		st = (st as Vector2) + w
	elif st is Dictionary:
		st = (st as Dictionary).duplicate()
		for k in ["x", "y", "anchor_x", "anchor_y", "x1", "x2", "y1", "y2"]:
			if st.has(k):
				st[k] = float(st[k]) + (w.x if k.begins_with("x") or k == "anchor_x" else w.y)
		if st.has("ground"):
			st["ground"] = st["ground"] + w
	if kind == "anthill":
		_vctx.anthill_pos = w
	ArtRegistry.draw(kind, self, st, _ctx)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1500, 900) / maxf(scale.x, 0.001)), Color("#3a4a50"))
	if _page == 0:
		scale = Vector2(3.0, 3.0)
		_page_a()
	else:
		scale = Vector2(1.45, 1.45)
		_page_b()


func _page_a() -> void:
	var y := 90.0
	_put("escudella", Vector2(80, y), {"x": 0.0, "y": -11.0, "steam_phase": 0.0})
	_put("mine", Vector2(220, y), {"x": 0.0, "y": -5.0, "triggered": false})
	_put("mine", Vector2(300, y), {"x": 0.0, "y": -5.0, "triggered": true})
	_put("pine_nut", Vector2(400, y), {"x": 0.0, "y": -6.0})
	_put("rovello", Vector2(500, y), {"x": 0.0, "y": 0.0, "r": 18.0, "squash": 1.0})
	_put("tombstone", Vector2(620, y), {"x": 0.0, "y": -10.0, "team": 0, "name": "PERLETA"})
	_put("tombstone", Vector2(720, y), {"x": 0.0, "y": -10.0, "team": 1, "name": "MARC"})
	_put("crate", Vector2(820, y), {"x": 0.0, "y": -10.0, "is_medkit": true, "parachuting": false})
	_put("crate", Vector2(920, y), {"x": 0.0, "y": -10.0, "is_medkit": false, "parachuting": false})
	_put("silk_nest", Vector2(1040, y), {"x": 0.0, "y": -20.0, "anchor_x": 0.0, "anchor_y": -50.0, "r": 13.0, "sway_phase": 0.0})
	_put("larvae", Vector2(1160, y), {"x": 0.0, "y": -6.0})
	_put("silk_web", Vector2(1300, y), {"x1": -30.0, "y1": -20.0, "x2": 30.0, "y2": -20.0, "vibration": 0.3})
	var types := ["MONTSERRAT", "CADAQUES", "TAULL", "DELTA_EBRE", "TARRACO", "PEDRAFORCA", "MONTBLANC", "X"]
	for i in types.size():
		for v in 3:
			_put("flora:" + types[i], Vector2(60.0 + i * 180.0 + v * 55.0, 330.0 + 0.0), {"x": 0.0, "y": 0.0, "type": types[i], "variant": v, "scale": 1.0, "phase": 0.0})
	_put("tuft", Vector2(120, 520), Vector2.ZERO)
	_put("tuft_front", Vector2(260, 520), {"ground": Vector2.ZERO, "seed": 3})
	_put("tuft_front", Vector2(340, 520), {"ground": Vector2.ZERO, "seed": 4})
	_vctx.anthill_pos = Vector2.ZERO
	_vctx.wave_time = 1.0
	_put("anthill", Vector2(520, 520), null)
	_vctx.wave_time = -100.0
	_put("anthill", Vector2(700, 520), null)


func _page_b() -> void:
	var rect := Rect2(-85, -55, 170, 110)
	_vctx.nest = {}
	var states := [[1.0, false, 0.0], [0.5, false, 0.0], [0.12, true, 0.3]]
	for i in 3:
		_fx.shown_frac = states[i][0]
		_fx.hit_t = states[i][2]
		_vctx.cold_active = states[i][1]
		var c := Vector2(260.0 + i * 480.0, 400.0) / scale.x
		_vctx.nest_rect = Rect2(c - rect.size * 0.5, rect.size)
		NestArt.draw_back(self, _vctx, _fx)
		NestArt.draw_front(self, _vctx)
