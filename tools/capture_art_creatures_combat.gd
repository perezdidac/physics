## Draws the combat creatures with sample states (sprite rig left, old vector right) into /tmp/claude-1000/sheet_creatures_combat_<name>.png.
##   CUCS_CAP=ant godot --path . res://tools/CaptureArtCreaturesCombat.tscn     (CUCS_ZOOM=3 sets the zoom; default 3)
## Needs a display.
extends Node

var CELL := Vector2(190.0, 150.0)


func _cases(nm: String) -> Array:
	var base := {"x": 0.0, "y": 0.0, "facing": 1.0, "grounded": true, "id": 1, "team": 0, "walk_cycle": 0.0}
	var out: Array = []
	match nm:
		"ant":
			var b: Dictionary = base.merged({"r": 9.0, "facing": 1.0}, true)
			for w in [0.0, 1.6, 3.2, 4.7]:
				out.append(b.merged({"walk_cycle": w}, true))
			out.append(b.merged({"bat_swing_timer": 0.4}, true))
			out.append(b.merged({"bat_swing_timer": 0.1}, true))
			out.append(b.merged({"hurt_timer": 0.8}, true))
			out.append(b.merged({"drowning": true}, true))
			out.append(b.merged({"facing": -1.0, "walk_cycle": 1.0}, true))
			out.append(b.merged({"grounded": false}, true))
		"egg":
			var b2: Dictionary = base.merged({"r": 11.0}, true)
			out.append(b2)
			out.append(b2.merged({"walk_cycle": 1.0, "facing": -1.0}, true))
			out.append(b2.merged({"hurt_timer": 0.8}, true))
			out.append(b2.merged({"hidden": true}, true))
			out.append(b2.merged({"drowning": true}, true))
	if nm == "caterpillar":
		var segs: Array = []
		for sg in 6:
			segs.append(Vector2(-(sg + 1) * 5.2, 4.0 + sin(float(sg)) * 0.6))
		var b4: Dictionary = base.merged({"r": 9.0, "y": -9.0, "kind": "CATERPILLAR", "segs": segs, "name": "Cuca"}, true)
		out.append(b4)
		out.append(b4.merged({"walk_cycle": 1.5, "team": 1}, true))
		out.append(b4.merged({"urticating_ticks": 3}, true))
		out.append(b4.merged({"hurt_timer": 0.8, "dizzy_timer": 1.0}, true))
		out.append(b4.merged({"drowning": true}, true))
		out.append(b4.merged({"metamorphosed": true, "grounded": false}, true))
		out.append(b4.merged({"jet_fuel": 50.0, "grounded": false, "facing": -1.0}, true))
		out.append(b4.merged({"body_colors": ["#8a5a2b", "#5a3a1c", "#2a1a0c"], "dorsal_color": "#e8d24a", "has_mustache": true}, true))
		out.append(b4.merged({"sliding": true, "slide_angle": 0.3}, true))
	if nm == "calosoma":
		var b5: Dictionary = base.merged({"r": 12.0, "y": -12.0}, true)
		for w in [0.0, 1.6, 3.2, 4.7]:
			out.append(b5.merged({"walk_cycle": w}, true))
		out.append(b5.merged({"bat_swing_timer": 0.3}, true))
		out.append(b5.merged({"hurt_timer": 0.8, "facing": -1.0}, true))
		out.append(b5.merged({"grounded": false, "walk_cycle": 1.0}, true))
		out.append(b5.merged({"drowning": true}, true))
	if nm == "bluetit" or nm == "greattit":
		var kd: String = "BLUE_TIT" if nm == "bluetit" else "GREAT_TIT"
		var b6: Dictionary = base.merged({"r": 13.0, "kind": kd, "ai_state": "approach", "flying": true, "y": -4.0}, true)
		for w in [0.0, 0.07, 0.15]:
			out.append(b6.merged({"id": int(w * 100.0)}, true))
		out.append(b6.merged({"ai_state": "idle", "flying": false, "y": -13.0}, true))
		out.append(b6.merged({"ai_state": "warn"}, true))
		out.append(b6.merged({"ai_state": "dive", "vx": 200.0, "vy": 220.0}, true))
		out.append(b6.merged({"ai_state": "fall"}, true))
		out.append(b6.merged({"hurt_timer": 0.8, "facing": -1.0}, true))
		out.append(b6.merged({"drowning": true, "ai_state": "idle", "flying": false}, true))
	if nm == "fly":
		var b7: Dictionary = base.merged({"r": 11.0, "kind": "SMALL_FLY", "ai_state": "approach", "flying": true, "y": -4.0}, true)
		out.append(b7)
		out.append(b7.merged({"id": 7}, true))
		out.append(b7.merged({"ai_state": "idle", "flying": false, "y": -2.0}, true))
		out.append(b7.merged({"ai_state": "warn"}, true))
		out.append(b7.merged({"ai_state": "dive", "vx": 200.0, "vy": 220.0}, true))
		out.append(b7.merged({"ai_state": "fall"}, true))
		out.append(b7.merged({"hurt_timer": 0.8, "facing": -1.0}, true))
		out.append(b7.merged({"drowning": true}, true))
	if nm == "boar":
		var b8: Dictionary = base.merged({"r": 20.0, "y": -20.0, "kind": "WILD_BOAR"}, true)
		out.append(b8)
		out.append(b8.merged({"ai_state": "charge"}, true))
		out.append(b8.merged({"ai_state": "charge", "id": 3, "facing": -1.0}, true))
		out.append(b8.merged({"hurt_timer": 0.8}, true))
	if nm == "forestry":
		var b9: Dictionary = base.merged({"r": 12.0, "y": -12.0, "kind": "FORESTRY_WORKER"}, true)
		out.append(b9)
		out.append(b9.merged({"walk_cycle": 1.2, "vx": 40.0}, true))
		out.append(b9.merged({"bat_swing_timer": 0.3}, true))
		out.append(b9.merged({"bat_swing_timer": 0.05, "facing": -1.0}, true))
		out.append(b9.merged({"hurt_timer": 0.8}, true))
	if nm == "cuckoo":
		var b10: Dictionary = base.merged({"r": 22.0, "y": -4.0}, true)
		for stn in ["", "INTENT", "ACT", "SATED"]:
			out.append(b10.merged({"boss_state": stn}, true))
		out.append(b10.merged({"hurt_timer": 0.8, "facing": -1.0}, true))
	if nm == "larva":
		for k in ["LARVA_L1", "LARVA_L2", "LARVA_L3", "LARVA_L4", "LARVA_L5"]:
			out.append(base.merged({"r": 9.0, "kind": k, "unit": {"art_scale": 1.0}}, true))
		var b3: Dictionary = base.merged({"r": 9.0, "kind": "LARVA_L4", "unit": {"art_scale": 1.0}}, true)
		out.append(b3.merged({"walk_cycle": 1.5}, true))
		out.append(b3.merged({"urticating_ticks": 3}, true))
		out.append(b3.merged({"hurt_timer": 0.8}, true))
		out.append(b3.merged({"dizzy_timer": 1.0}, true))
		out.append(b3.merged({"drowning": true, "facing": -1.0}, true))
	return out


func _ready() -> void:
	if OS.get_environment("CUCS_CELLW") != "":
		CELL = Vector2(float(OS.get_environment("CUCS_CELLW")), float(OS.get_environment("CUCS_CELLH")))
	var names: PackedStringArray = OS.get_environment("CUCS_CAP").split(",", false)
	if names.is_empty():
		names = PackedStringArray(["ant"])
	var zoom: float = float(OS.get_environment("CUCS_ZOOM")) if OS.get_environment("CUCS_ZOOM") != "" else 3.0
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for nm in names:
		await _capture(reg, nm, zoom)
	ArtRegistry.shutdown()
	get_tree().quit()


func _kind_of(nm: String) -> String:
	return {"ant": "creature:ANT", "egg": "creature:EGG", "larva": "creature:LARVA_L3", "caterpillar": "creature:CATERPILLAR", "boar": "creature:WILD_BOAR", "calosoma": "creature:CALOSOMA",
		"forestry": "creature:FORESTRY_WORKER", "fly": "creature:SMALL_FLY", "bluetit": "creature:BLUE_TIT", "greattit": "creature:GREAT_TIT"}.get(nm, "creature:" + nm.to_upper())


func _capture(reg: ArtRegistry, nm: String, zoom: float) -> void:
	var cases: Array = _cases(nm)
	var cols: int = 5
	var rows: int = ceili(float(cases.size()) / float(cols))
	var size := Vector2i(int(CELL.x * float(cols) * 2.0), int(CELL.y * float(rows)))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := DrawLayer.new()
	bg.draw_fn = func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color("#5d6f52"))
		ci.draw_rect(Rect2(Vector2(CELL.x * float(cols), 0), Vector2(2, size.y)), Color(0, 0, 0, 0.5))
	vp.add_child(bg)
	var art: ThingArt = reg.resolve(_kind_of(nm))
	var ctx: ArtContext = ArtContext.sample(1.3)
	for i in cases.size():
		var cell := Vector2(float(i % cols) * CELL.x, floorf(float(i) / float(cols)) * CELL.y)
		var halves: Array = [art, art.vector_fallback()]
		for h in 2:
			if halves[h] == null:
				continue
			var layer := DrawLayer.new()
			layer.position = cell + Vector2(CELL.x * 0.5 + float(h) * CELL.x * float(cols), CELL.y * 0.62)
			layer.scale = Vector2(zoom, zoom)
			var which: ThingArt = halves[h]
			var st: Dictionary = cases[i]
			layer.draw_fn = func(ci: CanvasItem) -> void:
				ci.draw_line(Vector2(-60, float(st.get("r", 9.0))) / zoom * 1.0, Vector2(60, float(st.get("r", 9.0))) / zoom * 1.0, Color(1, 1, 1, 0.2), 0.5)
				ctx.combat.boss_state = str(st.get("boss_state", ""))
				which.draw(ci, st, ctx)
			vp.add_child(layer)
	for i in 6:
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	var path := "/tmp/claude-1000/sheet_creatures_combat_%s.png" % nm
	img.save_png(path)
	print("CAPTURE ", path, " ", img.get_size())
	vp.queue_free()
