## Renders the boss arts in sample states to /tmp/claude-1000/sheet_bosses_1x.png and sheet_bosses_2.5x.png (rig vs old vector art).
##   godot --path . res://tools/CaptureArtBosses.tscn
extends Node

const COLS: int = 6
const CELL := Vector2(260.0, 230.0)
var _vp: SubViewport = null
var _wasp := WaspBossArt.new()


func _cases() -> Array:
	var tit: Dictionary = BossRigArt.sample_fighter("GREAT_TIT_BOSS", 22.0)
	var out: Array = []
	for st in ["perch", "approach", "warn", "dive", "fall"]:
		var f: Dictionary = tit.duplicate()
		f["ai_state"] = st
		f["flying"] = st != "perch"
		f["vx"] = 300.0
		f["vy"] = 260.0
		out.append(["boss:great_tit", st, f, ""])
	var tf: Dictionary = tit.duplicate()
	tf["hurt_timer"] = 1.0
	tf["ai_state"] = "approach"
	out.append(["boss:great_tit", "hurt", tf, ""])
	var ck: Dictionary = BossRigArt.sample_fighter("CUCKOO_BOSS", 22.0)
	for st in ["", "INTENT", "ACT", "SATED"]:
		out.append(["boss:cuckoo", st if st != "" else "fly", ck.duplicate(), st])
	var fl: Dictionary = BossRigArt.sample_fighter("TACHINID_FLY", 16.0)
	for st in ["approach", "warn", "dive", "perch", "fall"]:
		var f2: Dictionary = fl.duplicate()
		f2["ai_state"] = st
		f2["flying"] = st != "perch"
		out.append(["boss:tachinid_fly", st, f2, ""])
	var fm: Dictionary = BossRigArt.sample_fighter("BRIGADE_BOSS", 20.0)
	fm["walk_cycle"] = 1.2
	fm["vx"] = 0.0
	fm["bat_swing_timer"] = 0.0
	for st in ["stand", "walk", "swing", "line", "cart", "WINDED"]:
		var f3: Dictionary = fm.duplicate()
		var bs: String = ""
		if st == "walk":
			f3["vx"] = 60.0
		elif st == "swing":
			f3["bat_swing_timer"] = 0.25
		elif st == "WINDED":
			bs = "WINDED"
		out.append(["boss:foreman", st, f3, bs])
	for st in ["PATROL", "WARN", "DIVE", "RECOVER"]:
		out.append(["wasp", st, {}, ""])
	return out


func _ready() -> void:
	var zoom: float = 2.5 if OS.get_environment("ZOOM") == "1" else 1.0
	var cases: Array = _cases()
	var rows: int = ceili(float(cases.size()) / float(COLS))
	var size := Vector2i(int(CELL.x * zoom) * COLS, int(CELL.y * zoom) * rows)
	_vp = SubViewport.new()
	_vp.size = size
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bg := DrawLayer.new()
	bg.draw_fn = func(ci: CanvasItem) -> void: ci.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color("#4a6a52"))
	_vp.add_child(bg)
	for i in cases.size():
		var cs: Array = cases[i]
		var layer := DrawLayer.new()
		layer.position = Vector2(float(i % COLS) * CELL.x, floorf(float(i) / float(COLS)) * CELL.y) * zoom + Vector2(CELL.x * 0.5, CELL.y * 0.6) * zoom
		layer.scale = Vector2(zoom, zoom)
		var vctx := ViewCtx.new()
		vctx.t_now = 1.3
		vctx.boss_state = cs[3]
		if cs[1] == "line":
			vctx.boss_intent = {"kind": "LINE"}
			vctx.boss = cs[2]
		elif cs[1] == "cart":
			vctx.boss_intent = {"attack_id": "CARTRIDGE"}
		var ctx := ArtContext.of(vctx)
		var id: String = cs[0]
		var st: Variant = cs[2]
		var lbl: String = "%s %s" % [id, cs[1]]
		layer.draw_fn = func(ci: CanvasItem) -> void:
			ci.draw_line(Vector2(-100.0, 22.0), Vector2(100.0, 22.0), Color(1, 1, 1, 0.2), 1.0)
			if id == "wasp":
				_wasp.draw(ci, Vector2.ZERO, 0.0, 1.0, 1.3, str(cs[1]), 1.3)
			else:
				ArtRegistry.draw(id, ci, st, ctx)
			ViewUtil.text(ci, lbl, Vector2(0.0, -CELL.y * 0.55), 11, Color.WHITE, true)
		_vp.add_child(layer)
	for i in 6:
		await get_tree().process_frame
	var path: String = "/tmp/claude-1000/sheet_bosses_%s.png" % ("2.5x" if zoom > 1.0 else "1x")
	_vp.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	ArtRegistry.shutdown()
	get_tree().quit()
