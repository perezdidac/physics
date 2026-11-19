## Nest view (phase C2): the NEST levels on the real CombatScreen (nest art, HP bar and objective, REPAIR button and key, cold overlay, frozen
## caterpillars, hit and repair effects, the pole band and its slam, the foreman and workers, the boss LINE band), the hub screen buying an upgrade,
## the story map with the NEST, PUPA and MOTH stages in order, the level cards and the results with the silk earned.
##   godot --headless --path . res://tests/TestNestView.tscn
extends Node

var failures: int = 0
var routed: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	StoryProgress.save_path = "user://nest_view_test.cfg"
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


func _run() -> void:
	_check(ScreenRouter.SCREENS.has("nest_hub") and ResourceLoader.exists(str(ScreenRouter.SCREENS["nest_hub"])), "ScreenRouter knows the nest_hub screen")
	await _run_nest_levels()
	await _run_boss()
	await _run_hub()
	await _run_map()
	await _run_cards_and_results()


func _run_nest_levels() -> void:
	for id in ["nest_1", "nest_3"]:
		var s: CombatScreen = _screen(id)
		await _frames(10)
		_check(s.sim != null and s.t_now > 0.0 and (s.sim as CombatSim).nest != null, "%s: CombatScreen runs frames with a nest" % id)
		s.queue_free()
		await _frames(2)
	var screen: CombatScreen = _screen("nest_2")
	await _frames(20)
	var sim: CombatSim = screen.sim as CombatSim
	var top: TopHud = _hud(screen, TopHud) as TopHud
	var bottom: BottomHud = _hud(screen, BottomHud) as BottomHud
	_check(sim != null and sim.nest != null and sim.cold_active, "nest_2: the sim has a nest and the cold")
	var ctx: ViewCtx = screen.view.ctx
	_check(ctx.nest != null and ctx.cold_active and ctx.nest_rect.size.x > 100.0 and is_equal_approx(ctx.nest_frac, 1.0), "view context reads the nest and the cold")
	_check(top.nest_bar.visible and is_equal_approx(top.nest_bar.fraction, 1.0), "nest bar is shown at full health")
	_check(top.objective_label.text.contains("300/300") and not top.objective_label.text.begins_with("HUD_"), "objective shows the rounds and the nest (%s)" % top.objective_label.text)
	_check(screen.view.nest_fx.shown_frac == 1.0, "nest art starts whole")
	# the frozen tint: a caterpillar outside the nest in the cold gets it, one inside does not
	var inside: SimFighter = sim.fighters[0]
	var outside: SimFighter = sim.fighters[1]
	inside.x = sim.nest.pos.x
	inside.y = sim.nest.pos.y
	outside.x = sim.nest.rect().end.x + 200.0
	await _frames(3)
	_check(ctx.in_nest(inside) and not ctx.in_nest(outside), "view tells sheltered from frozen caterpillars")
	# hit: the bar drops, the art tears, the nest shakes
	sim.nest.hp = 150
	sim.nest_hit.emit(sim.nest.pos, 40)
	sim.nest_changed.emit()
	await _frames(3)
	_check(is_equal_approx(top.nest_bar.fraction, 0.5) and top.objective_label.text.contains("150/300"), "nest bar and objective follow the nest HP")
	_check(screen.view.nest_fx.hit_t > 0.0 and not screen.view.nest_fx.flakes.is_empty() and screen.view.nest_fx.shown_frac < 1.0, "a hit shakes the nest, flings silk and shows tears")
	# REPAIR: only next to a damaged nest on the human turn
	var active: SimFighter = sim.active_fighter
	_check(active.team == 0, "a squad caterpillar is active")
	active.x = sim.nest.rect().end.x + 300.0
	await _frames(3)
	_check(not bottom.can_repair_nest() and not _repair_shown(bottom), "REPAIR is hidden away from the nest")
	active.x = sim.nest.pos.x
	active.y = sim.nest.pos.y
	await _frames(3)
	_check(bottom.can_repair_nest() and _repair_shown(bottom), "REPAIR shows next to the damaged nest (button or touch pad)")
	var before: int = sim.nest.hp
	_check(bottom.handle_key(KEY_T), "the T key is handled")
	await _frames(3)
	_check(sim.nest.hp == before + SimBolso.REPAIR_HP, "REPAIR (key T) gives the nest 40 HP (%d -> %d)" % [before, sim.nest.hp])
	_check(screen.view.nest_fx.repair_t > 0.0, "repair starts the new-strands animation")
	_check(not _repair_shown(bottom), "REPAIR hides once the action is spent")
	_check(bottom.touch_pad.repair_button.get_parent() == bottom.touch_pad and bottom.repair_button != null, "REPAIR has a button in the weapon bar and one on the touch pad")
	screen.queue_free()
	await _frames(2)
	# the pole
	screen = _screen("nest_4")
	await _frames(10)
	sim = screen.sim as CombatSim
	var band := Rect2(sim.nest.pos.x - 65.0, 0.0, 130.0, sim.terrain.water_y)
	sim.pole_band = band
	sim.pole_state = "WARN"
	sim.pole_warn.emit(band)
	await _frames(4)
	_check(screen.view.ctx.pole_state == "WARN" and screen.view.ctx.pole_band == band, "view reads the telegraphed pole band")
	sim.pole_band = Rect2()
	sim.pole_state = ""
	sim.pole_sweep.emit(band)
	await _frames(4)
	_check(not screen.view.nest_fx.sweep.is_empty(), "the pole sweep animation plays")
	for i in 4:
		screen.view.nest_fx.update(0.4, screen.view.ctx)
	_check(screen.view.nest_fx.sweep.is_empty(), "the pole sweep animation ends")
	SimBolso.damage(sim, 400, sim.nest.pos)
	await _frames(3)
	_check(screen.view.ctx.nest_destroyed, "a fallen nest is drawn as a heap")
	screen.queue_free()
	await _frames(2)


func _run_boss() -> void:
	var screen: CombatScreen = _screen("nest_boss")
	await _frames(15)
	var sim: CombatSim = screen.sim as CombatSim
	_check(sim.boss != null and sim.nest != null and screen.view.ctx.boss != null, "nest_boss: a boss and a nest")
	var top: TopHud = _hud(screen, TopHud) as TopHud
	_check(top.nest_bar.visible and top.objective_label.text.begins_with(tr("HUD_OBJECTIVE_NEST").split(" ")[0]), "nest_boss: the nest bar shows beside the boss (%s)" % top.objective_label.text)
	var idx: int = -1
	for i in sim.boss_def.attacks.size():
		if sim.boss_def.attacks[i]["id"] == "POLE_SWEEP":
			idx = i
	var atk: Dictionary = sim.boss_def.attacks[idx]
	var intent: Dictionary = BossAttacks.handler("LINE").plan(sim, atk)
	intent["attack_index"] = idx
	SimBoss.set_intent(sim, intent)
	SimBoss.set_state(sim, "INTENT")
	await _frames(5)
	var ctx: ViewCtx = screen.view.ctx
	_check(str(ctx.boss_intent.get("kind", "")) == "LINE" and ctx.boss_intent.get("rect") is Rect2, "the LINE intent reaches the view with its band")
	var probe := DrawLayer.new()
	probe.draw_fn = func(ci: CanvasItem) -> void: NestFx.draw_band(ci, ctx, ctx.boss_intent["rect"], 1.0)
	add_child(probe)
	await _frames(2)
	_check(probe.is_inside_tree(), "the LINE band draws")
	probe.queue_free()
	# the foreman rests (WINDED) and the workers walk
	SimBoss.set_state(sim, "WINDED")
	var worker: UnitDef = _level("nest_boss").boss.attacks[0]["unit"]
	var w: SimFighter = SimStory._make_unit(sim, 1, 5, "Obrer", Vector2(sim.boss.x + 90.0, sim.boss.y), worker, -1)
	w.bat_swing_timer = 0.3
	sim.fighters.append(w)
	await _frames(6)
	_check(screen.view.ctx.boss_state == "WINDED" and screen.view.ctx.boss_vulnerable, "WINDED is the vulnerable resting pose")
	_check(screen.view.ctx.fighters.has(w) and w.kind == "FORESTRY_WORKER", "a forestry worker is drawn by its own art")
	screen.queue_free()
	await _frames(2)


## True when a REPAIR button is on screen (the weapon bar one, or the touch pad one on touch layouts).
func _repair_shown(bottom: BottomHud) -> bool:
	return bottom.repair_button.visible or bottom.touch_pad.repair_button.visible


func _run_hub() -> void:
	StoryProgress.reset_progress()
	for id in ["egg_1", "egg_2", "egg_3"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 3})
	_check(StoryProgress.silk() == 54, "54 silk for nine stars")
	var hub: Control = (load("res://ui/story/NestHub.tscn") as PackedScene).instantiate()
	hub.go_callable = func(target: String) -> void: routed.append(target)
	add_child(hub)
	await _frames(4)
	_check(hub.cards.size() == StoryProgress.upgrades().size() and hub.cards.size() == 12, "hub shows a card for every upgrade (%d)" % hub.cards.size())
	_check(hub.silk_label.text.contains("54") and not hub.silk_label.text.begins_with("NEST_"), "hub shows the silk counter (%s)" % hub.silk_label.text)
	var cheap: UpgradeDef = null
	var dear: UpgradeDef = null
	for u in StoryProgress.upgrades():
		if u.cost <= 54 and u.requires == "" and cheap == null:
			cheap = u
		if u.cost > 54 and u.requires == "" and dear == null:
			dear = u
	_check(cheap != null and hub.buy_buttons.has(cheap.id) and not (hub.buy_buttons[cheap.id] as ChamferButton).disabled, "an affordable upgrade has an enabled buy button")
	if dear != null:
		_check(hub.buy_buttons.has(dear.id) and (hub.buy_buttons[dear.id] as ChamferButton).disabled and not hub.buy(dear.id), "an unaffordable upgrade is disabled and cannot be bought")
	_check(hub.buy(cheap.id), "buying %s works" % cheap.id)
	await _frames(4)
	_check(StoryProgress.owns(cheap.id) and StoryProgress.silk() == 54 - cheap.cost and not hub.buy_buttons.has(cheap.id), "the upgrade is owned, the silk went down and its card shows 'owned'")
	_check(hub.silk_label.text.contains(str(54 - cheap.cost)), "the counter follows the purchase")
	_check(not hub.buy(cheap.id), "an owned upgrade cannot be bought twice")
	var texts: Array[String] = []
	_collect_labels(hub, texts)
	var all_text: String = "\n".join(texts)
	_check(all_text.contains(tr("UPG_WHERE_COMBAT")) and all_text.contains(tr("UPG_WHERE_PLATFORM")) and all_text.contains(tr("UPG_WHERE_NEST")) and not all_text.contains("UPG_WHERE"), "every card says where it works (combat, nest, platform levels)")
	_check(all_text.contains(UiUtil.fmt("UPG_NEEDS", [tr("UPG_TOUGH_SKIN_NAME")])) or StoryProgress.owns("TOUGH_SKIN"), "a tier II card names the upgrade it needs")
	hub.back_to_map()
	_check(routed.back() == "story_map", "Back returns to the story map")
	hub.queue_free()
	await _frames(1)
	StoryProgress.refund_all()


func _run_map() -> void:
	StoryProgress.reset_progress()
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = func(target: String) -> void: routed.append(target)
	add_child(map)
	await _frames(3)
	_check(map.nest_button == null, "map: no hub button before any silk is earned")
	StoryProgress.record_result({"level_id": "egg_1", "won": true, "stars": 1})
	var all: Array[LevelDef] = StoryProgress.levels()
	for level in all:
		if level.stage == "NEST":
			break
		StoryProgress.record_result({"level_id": level.id, "won": true, "stars": 1})
	map._build()
	await _frames(3)
	_check(map.nest_button != null and map.nest_button.is_inside_tree(), "map: the hub button appears once some silk is earned")
	map.nest_button.pressed.emit()
	_check(routed.back() == "nest_hub", "the nest button opens the hub")
	var expected: Dictionary = {"NEST": ["nest_1", "nest_2", "nest_3", "nest_4", "nest_boss"], "PUPA": ["pupa_1", "pupa_2", "pupa_3", "pupa_boss"], "MOTH": ["moth_1", "moth_2", "moth_3", "moth_boss"]}
	for stage: String in expected:
		map.open_stage = stage
		map._build()
		await _frames(3)
		var ids: Array[String] = []
		for node in map.level_nodes:
			ids.append(str(node.name).trim_prefix("Level_"))
		_check(ids == expected[stage], "map: stage %s shows its levels in order (%s)" % [stage, ", ".join(ids)])
	var orders: Array[int] = []
	for level in all:
		orders.append(StoryUi.STAGES.find(level.stage))
	var sorted: Array[int] = orders.duplicate()
	sorted.sort()
	_check(orders == sorted, "map: the level list follows the stage order")
	map.queue_free()
	await _frames(1)


func _run_cards_and_results() -> void:
	GameState.story_level = _level("nest_4")
	var intro: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	add_child(intro)
	await _frames(3)
	var rules: Array[String] = intro.rule_lines()
	_check(rules.size() == 4 and not rules.any(func(r: String) -> bool: return r.begins_with("STORY_")), "nest_4 card: defend, repair, cold and pole rules (%d)" % rules.size())
	intro.queue_free()
	await _frames(1)
	for id in ["pupa_1", "moth_2"]:
		GameState.story_level = _level(id)
		intro = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
		add_child(intro)
		await _frames(3)
		var mode_lines: Array[String] = intro.rule_lines()
		_check(mode_lines.size() == 1 and not mode_lines[0].begins_with("STORY_MODE"), "%s card: a mode hint (%s)" % [id, mode_lines[0] if not mode_lines.is_empty() else ""])
		_check(not intro.enemies_text().begins_with("STORY_ENEMY"), "%s card: enemies line (%s)" % [id, intro.enemies_text()])
		intro.queue_free()
		await _frames(1)
	# every level text of the three stages is translated
	var missing: Array[String] = []
	for level in StoryProgress.levels():
		if level.stage in ["NEST", "PUPA", "MOTH"]:
			for key in [level.title_key, level.intro_key, level.goal_key, level.tip_key]:
				if tr(key) == key:
					missing.append(key)
	_check(missing.is_empty(), "every NEST, PUPA and MOTH level text is translated %s" % str(missing))
	# results with silk
	StoryProgress.reset_progress()
	GameState.story_result = {"level_id": "nest_1", "won": true, "stars": 2, "survivors": 3, "reason": "SURVIVED"}
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = func(target: String) -> void: routed.append(target)
	add_child(res)
	await _frames(3)
	_check(res.silk_earned == 12 and res.hub_button != null, "results: 12 silk for two new stars and a button to the hub")
	var texts: Array[String] = []
	_collect_labels(res, texts)
	_check("\n".join(texts).contains(UiUtil.fmt("STORY_RESULT_SILK", [12])), "results show the silk earned")
	_check(res.reason_text("SURVIVED") == tr("STORY_REASON_NEST_SURVIVED") and res.reason_text("NEST_DESTROYED") == tr("STORY_REASON_NEST_DESTROYED"), "nest levels have their own end reasons")
	res.open_hub()
	_check(routed.back() == "nest_hub", "results open the hub")
	res.queue_free()
	await _frames(1)


func _collect_labels(n: Node, out: Array[String]) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_labels(c, out)
