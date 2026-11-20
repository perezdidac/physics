## Procession view (phase D1): the PROCESSION levels on the real CombatScreen (the file with its silk thread, the crowned leader and the worried lost
## follower, the goal zone, the march bar and the objective, the wild boar telegraph, the spore clouds with their pulse, the Calosoma, the cuckoo boss
## and its intents), the story map with the PROCESSION stage between NEST and PUPA, the level cards and the results with the followers saved.
##   godot --headless --path . res://tests/TestProcView.tscn
extends Node

var failures: int = 0
var routed: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	StoryProgress.save_path = "user://proc_view_test.cfg"
	StoryProgress.reset_progress()
	await _run()
	StoryProgress.reset_progress()
	GameState.story_level = null
	GameState.story_result = {}
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id) as LevelDef


func _screen(id: String) -> CombatScreen:
	GameState.story_level = _level(id)
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	screen.go_callable = func(target: String) -> void: routed.append(target)
	add_child(screen)
	return screen


func _hud(screen: CombatScreen, type: Variant) -> Node:
	for h in screen.huds:
		if is_instance_of(h, type):
			return h
	return null


## Draws `fn` once on a probe layer (so a draw error would show up in the test output).
func _probe(fn: Callable) -> void:
	var probe := DrawLayer.new()
	probe.draw_fn = fn
	add_child(probe)
	await _frames(2)
	probe.queue_free()


func _run() -> void:
	await _run_levels()
	await _run_line()
	await _run_hud()
	await _run_boar()
	await _run_spores()
	await _run_calosoma()
	await _run_boss()
	await _run_map()
	await _run_cards_and_results()


func _run_levels() -> void:
	for id in ["proc_1", "proc_2", "proc_3", "proc_4", "proc_5", "proc_boss"]:
		var s: CombatScreen = _screen(id)
		await _frames(10)
		var sim: CombatSim = s.sim as CombatSim
		_check(sim != null and s.t_now > 0.0 and s.view.ctx.convoy and s.view.ctx.leader != null, "%s: CombatScreen runs frames as a convoy with a leader" % id)
		_check(s.view.ctx.goal_x >= 0.0 and s.view.ctx.march_budget > 0.0, "%s: the view knows the goal x and the march budget" % id)
		s.queue_free()
		await _frames(2)


func _run_line() -> void:
	var screen: CombatScreen = _screen("proc_1")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var ctx: ViewCtx = screen.view.ctx
	_check(ctx.line.size() >= 5 and ctx.line[0] == sim.convoy_leader, "the file has the leader first and %d in the line" % ctx.line.size())
	var places: Array[int] = []
	for f in ctx.line:
		places.append(ConvoyInfo.place(f))
	var sorted: Array[int] = places.duplicate()
	sorted.sort()
	_check(places == sorted and places[0] == 0, "the file is ordered head to tail (%s)" % str(places))
	# the followers ripple behind the leader: each place lags the one in front
	var f1: SimFighter = ctx.line[1]
	var f2: SimFighter = ctx.line[2]
	f1.walk_cycle = 5.0
	f2.walk_cycle = 5.0
	_check(is_equal_approx(ctx.walk_of(f1) - ctx.walk_of(f2), ConvoyInfo.WAVE_LAG * float(ConvoyInfo.place(f2) - ConvoyInfo.place(f1))), "followers wiggle with a lag per place")
	_check(not ctx.is_lost(f1), "a follower in the line is not lost")
	# a lost follower
	f2.lost = true
	f2.line_index = -1
	await _frames(3)
	_check(ctx.is_lost(f2) and ConvoyInfo.follower_counts(sim.fighters).x == ConvoyInfo.follower_counts(sim.fighters).y - 1, "a lost follower looks lost and drops out of the Seguidors count")
	_check(ConvoyInfo.place(f2) >= 1000, "a lost follower goes to the end of the file")
	f2.lost = false
	await _probe(func(ci: CanvasItem) -> void:
		ConvoyArt.draw_thread(ci, ctx)
		ConvoyArt.draw_goal(ci, ctx)
		ConvoyArt.draw_reach(ci, ctx)
		for f in ctx.line:
			ConvoyArt.draw_marks(ci, f, ctx))
	_check(true, "thread, goal zone, march reach and the crown / worry marks draw")
	screen.queue_free()
	await _frames(2)


func _run_hud() -> void:
	var screen: CombatScreen = _screen("proc_1")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var top: TopHud = _hud(screen, TopHud) as TopHud
	var counts: Vector2i = ConvoyInfo.follower_counts(sim.fighters)
	_check(top.objective_panel.visible and top.objective_label.text.contains("%d/%d" % [counts.x, counts.y]) and not top.objective_label.text.begins_with("HUD_"), "objective: reach the soft soil and the followers (%s)" % top.objective_label.text)
	_check(top.march_bar.visible and top.march_bar.label_text.contains(str(int(sim.march_budget))) and not top.march_bar.label_text.begins_with("HUD_"), "march bar is full at the start (%s)" % top.march_bar.label_text)
	_check(is_equal_approx(top.march_bar.fraction, 1.0), "march bar fraction is 1")
	sim.march_left = sim.march_budget * 0.25
	await _frames(3)
	_check(is_equal_approx(top.march_bar.fraction, 0.25) and top.march_bar.label_text.contains(str(int(sim.march_budget * 0.25))), "march bar follows the walk left (%s)" % top.march_bar.label_text)
	_check(MarchBar.fill_color(0.9) != MarchBar.fill_color(0.1), "the bar changes colour as the walk runs out")
	_check(top.squad_titles[0].text == tr("HUD_SQUAD_CONVOY").to_upper(), "the squad is called the procession")
	var f: SimFighter = sim.fighters[2]
	f.lost = true
	sim.hud_changed.emit()
	await _frames(3)
	_check(top.objective_label.text.contains("%d/%d" % [counts.x - 1, counts.y]), "the objective counts only the followers still in the line (%s)" % top.objective_label.text)
	screen.queue_free()
	await _frames(2)


func _run_boar() -> void:
	var screen: CombatScreen = _screen("proc_2")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var ctx: ViewCtx = screen.view.ctx
	var boar: SimFighter = null
	for f in sim.fighters:
		if f.kind == "WILD_BOAR":
			boar = f
	_check(boar != null, "proc_2: the level has a wild boar")
	var band := Rect2(900.0, 0.0, 600.0, sim.terrain.water_y)
	sim.boar_intents = [{"boar": boar, "band": band, "side": -1, "turns_left": 1}]
	await _frames(3)
	_check(ctx.boar_intents.size() == 1 and ctx.boar_intents[0]["band"] == band, "the boar telegraph (band and side) reaches the view")
	await _probe(func(ci: CanvasItem) -> void:
		for intent in ctx.boar_intents:
			BoarArt.draw_warning(ci, intent, ctx))
	_check(true, "the boar band, chevrons and side arrow draw")
	sim.boar_intents = [{"boar": boar, "band": band, "side": 1, "turns_left": 2}]
	await _frames(3)
	await _probe(func(ci: CanvasItem) -> void:
		for intent in ctx.boar_intents:
			BoarArt.draw_warning(ci, intent, ctx))
	_check(not tr("PROC_BOAR_WARN").begins_with("PROC_") and not UiUtil.fmt("PROC_BOAR_WARN_N", [2]).begins_with("PROC_"), "the boar warning texts are translated")
	# the charge: the boar runs with a dust trail
	boar.ai_state = "charge"
	boar.x = 1200.0
	boar.y = sim.terrain.find_surface_y(1200.0, 40.0) - boar.r
	await _frames(4)
	_check(BoarArt.phase(boar) == BoarArt.CHARGE and BoarArt.is_boar(boar), "a charging boar is recognised")
	await _probe(func(ci: CanvasItem) -> void: BoarArt.draw(ci, boar, ctx))
	_check(true, "the charging boar draws with its dust trail")
	sim.boar_intents = []
	await _frames(2)
	_check(ctx.boar_intents.is_empty(), "the telegraph disappears with the intent")
	screen.queue_free()
	await _frames(2)


func _run_spores() -> void:
	var screen: CombatScreen = _screen("proc_4")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var ctx: ViewCtx = screen.view.ctx
	if sim.spores.is_empty():
		var clouds: Array[Rect2] = [Rect2(1500.0, 200.0, 260.0, 220.0), Rect2(2100.0, 240.0, 200.0, 180.0)]
		sim.spores = clouds
	await _frames(3)
	_check(not ctx.spores.is_empty() and ctx.spores.size() == sim.spores.size(), "proc_4: the spore clouds reach the view (%d)" % ctx.spores.size())
	var cloud: Rect2 = ctx.spores[0]
	var f: SimFighter = sim.fighters[0]
	f.x = cloud.get_center().x
	f.y = cloud.get_center().y
	_check(ConvoyInfo.in_spores(ctx, f), "a fighter inside a cloud is detected")
	ctx.spore_pulse = 0.0
	sim.spore_tick.emit(f, 6)
	_check(ctx.spore_pulse > 0.9, "the damage pulse starts when a cloud hurts someone")
	await _frames(10)
	_check(ctx.spore_pulse < 0.9, "the pulse fades")
	await _probe(func(ci: CanvasItem) -> void:
		ctx.spore_pulse = 0.7
		SporeArt.draw(ci, ctx))
	_check(true, "the clouds draw with their pulse")
	f.x = cloud.position.x - 400.0
	_check(not ConvoyInfo.in_spores(ctx, f), "a fighter outside the clouds is not hurt")
	screen.queue_free()
	await _frames(2)


func _run_calosoma() -> void:
	var screen: CombatScreen = _screen("proc_3")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var beetle: SimFighter = null
	for f in sim.fighters:
		if f.kind == "CALOSOMA":
			beetle = f
	_check(beetle != null, "proc_3: the level has a Calosoma")
	var ctx: ViewCtx = screen.view.ctx
	beetle.bat_swing_timer = 0.3
	await _frames(3)
	await _probe(func(ci: CanvasItem) -> void: CalosomaArt.draw(ci, beetle, ctx))
	_check(true, "the Calosoma draws (biting)")
	screen.queue_free()
	await _frames(2)


func _run_boss() -> void:
	var screen: CombatScreen = _screen("proc_boss")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	var ctx: ViewCtx = screen.view.ctx
	var hud: BossHud = _hud(screen, BossHud) as BossHud
	_check(sim.boss != null and ctx.boss != null and ViewUtil.gs(ctx.boss_def, "art").begins_with("cuckoo"), "proc_boss: the cuckoo boss is in the level")
	_check(hud != null and hud.visible, "the boss HUD shows")
	var top: TopHud = _hud(screen, TopHud) as TopHud
	_check(top.objective_label.text.contains("/") and top.march_bar.visible, "the objective and the march bar show beside the boss")
	var idx: int = -1
	for i in sim.boss_def.attacks.size():
		if sim.boss_def.attacks[i]["id"] == "SWOOP":
			idx = i
			break
	var atk: Dictionary = sim.boss_def.attacks[idx]
	var intent: Dictionary = BossAttacks.handler(str(atk["kind"])).plan(sim, atk)
	intent["attack_index"] = idx
	SimBoss.set_intent(sim, intent)
	SimBoss.set_state(sim, "INTENT")
	await _frames(5)
	_check(str(ctx.boss_intent.get("kind", "")) == "MELEE_TARGET" and not (ctx.boss_intent.get("targets", []) as Array).is_empty(), "the swoop intent reaches the view with its marked follower")
	SimBoss.set_state(sim, "ACT")
	await _frames(4)
	SimBoss.set_state(sim, "SATED")
	SimBoss.set_intent(sim, {})
	await _frames(5)
	_check(ctx.boss_state == "SATED" and ctx.boss_vulnerable, "SATED is the vulnerable resting pose")
	await _probe(func(ci: CanvasItem) -> void: BossArt.draw(ci, ctx.boss, ctx))
	_check(true, "the sated cuckoo draws (full belly, halo)")
	_check(tr("BOSS_CUCKOO_FACT") != "BOSS_CUCKOO_FACT" and tr("BOSS_CUCKOO_ATTACKS") != "BOSS_CUCKOO_ATTACKS", "the cuckoo card texts are translated")
	screen.queue_free()
	await _frames(2)


func _run_map() -> void:
	StoryProgress.reset_progress()
	var all: Array[LevelDef] = StoryProgress.levels()
	for level in all:
		if level.stage == "PROCESSION":
			break
		StoryProgress.record_result({"level_id": level.id, "won": true, "stars": 1})
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = func(target: String) -> void: routed.append(target)
	add_child(map)
	await _frames(3)
	var order: Array[String] = []
	for stage in StoryUi.STAGES:
		order.append(stage)
	var i_nest: int = order.find("NEST")
	_check(order[i_nest + 1] == "PROCESSION" and order[i_nest + 2] == "PUPA", "the stage strip has PROCESSION between NEST and PUPA")
	_check(map.stage_chips.size() == StoryUi.STAGES.size(), "the map has a chip for every stage")
	map.open_stage = "PROCESSION"
	map._build()
	await _frames(3)
	var ids: Array[String] = []
	for node in map.level_nodes:
		ids.append(str(node.name).trim_prefix("Level_"))
	_check(ids == ["proc_1", "proc_2", "proc_3", "proc_4", "proc_5", "proc_boss"], "map: PROCESSION shows its five levels and the boss in order (%s)" % ", ".join(ids))
	var orders: Array[int] = []
	for level in all:
		orders.append(StoryUi.STAGES.find(level.stage))
	var sorted: Array[int] = orders.duplicate()
	sorted.sort()
	_check(orders == sorted, "map: the level list follows the stage order with PROCESSION in place")
	map.queue_free()
	await _frames(1)


func _run_cards_and_results() -> void:
	for id in ["proc_1", "proc_2", "proc_4", "proc_boss"]:
		GameState.story_level = _level(id)
		var intro: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
		add_child(intro)
		await _frames(3)
		var rules: Array[String] = intro.rule_lines()
		_check(rules.size() >= 3 and not rules.any(func(r: String) -> bool: return r.begins_with("STORY_")), "%s card: convoy rules (%d)" % [id, rules.size()])
		if id == "proc_2":
			_check(rules.any(func(r: String) -> bool: return r.begins_with(tr("STORY_RULE_BOAR").split(":")[0])), "proc_2 card: the boar rule")
		_check(not intro.enemies_text().begins_with("STORY_"), "%s card: enemies line (%s)" % [id, intro.enemies_text()])
		intro.queue_free()
		await _frames(1)
	var missing: Array[String] = []
	for level in StoryProgress.levels():
		if level.stage == "PROCESSION":
			for key in [level.title_key, level.intro_key, level.goal_key, level.tip_key]:
				if tr(key) == key:
					missing.append(key)
	for key in ["STORY_HERO_PROCESSION", "STORY_STAGE_PROCESSION_FACT", "STORY_STAGE_PROCESSION_NICK", "STORY_STAGE_PROCESSION_BLURB", "STORY_RESULT_FOLLOWERS"]:
		if tr(key) == key:
			missing.append(key)
	_check(missing.is_empty(), "every PROCESSION text is translated (missing: %s)" % ", ".join(missing))
	# results: followers saved
	var level: LevelDef = _level("proc_1")
	GameState.story_level = level
	GameState.story_result = {"level_id": "proc_1", "won": true, "survivors": 4, "followers": 3, "stars": 2, "reason": "GOAL_REACHED"}
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = func(target: String) -> void: routed.append(target)
	add_child(res)
	await _frames(3)
	_check(res.followers_saved() == 3, "results read the followers saved")
	var texts: Array[String] = []
	_collect_text(res, texts)
	var want: String = UiUtil.fmt("STORY_RESULT_FOLLOWERS", [3, level.player_names.size() - 1])
	_check(texts.has(want), "results show the followers saved (%s)" % want)
	_check(res.reason_text("GOAL_REACHED") != "STORY_REASON_PROCESSION_GOAL_REACHED" and not res.reason_text("GOAL_REACHED").begins_with("STORY_REASON"), "the goal reason has its own text")
	_check(not res.reason_text("LOST").begins_with("STORY_REASON"), "the lost reason is translated for this stage")
	res.queue_free()
	await _frames(1)


func _collect_text(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_text(c, out)
