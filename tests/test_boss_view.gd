## Boss view: the larva_boss screen (boss bar, intent markers, status icons, phase and defeat reactions to the sim signals, the route to
## the results), the Cuca levels on the real CombatScreen (L3-L5 larvae, great tits, the great tit boss), the story map with the boss nodes
## and the Cuca stage, and the boss card of the level intro.
##   godot --headless --path . res://tests/TestBossView.tscn
extends Node

var failures: int = 0
var routed: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	StoryProgress.save_path = "user://boss_view_test.cfg"
	StoryProgress.reset_progress()
	await _run()
	StoryProgress.reset_progress()
	GameState.story_level = null
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


func _boss_hud(screen: CombatScreen) -> BossHud:
	for h in screen.huds:
		if h is BossHud:
			return h as BossHud
	return null


func _run() -> void:
	await _run_larva_boss()
	for id in ["cuca_1", "cuca_2", "cuca_3", "cuca_4", "cuca_5", "cuca_6", "cuca_boss"]:
		await _run_cuca(id)
	await _run_map_and_intro()


func _run_larva_boss() -> void:
	var screen: CombatScreen = _screen("larva_boss")
	await _frames(20)
	var sim: CombatSim = screen.sim as CombatSim
	var hud: BossHud = _boss_hud(screen)
	_check(sim != null and sim.boss != null and screen.t_now > 0.0, "larva_boss: CombatScreen runs frames with a boss")
	_check(hud != null and hud.visible and hud.bar.fraction == 1.0, "boss bar shows at full health")
	_check(hud.name_label.text.to_upper() == tr(sim.boss_def.name_key).to_upper() and not hud.name_label.text.begins_with("BOSS_"), "boss bar shows the translated name (%s)" % hud.name_label.text)
	_check(hud.bar.phase_marks.size() == 1 and hud.bar.phase == 1, "bar has one phase mark and the phase 1 pip")
	_check(hud.banner.visible, "intro banner is showing")
	sim.boss.hp = 90
	sim.boss_changed.emit()
	_check(is_equal_approx(hud.bar.fraction, 0.5), "bar follows boss_changed (hp 90 of 180)")
	# intent markers
	var idx: int = 0
	for i in sim.boss_def.attacks.size():
		if sim.boss_def.attacks[i]["id"] == "LAY_EGGS":
			idx = i
			break
	var atk: Dictionary = sim.boss_def.attacks[idx]
	var intent: Dictionary = BossAttacks.handler(str(atk["kind"])).plan(sim, atk)
	intent["attack_index"] = idx
	SimBoss.set_intent(sim, intent)
	await _frames(3)
	_check(hud.intent_label.visible and hud.intent_label.text == str(intent["label"]), "intent line shows the label (%s)" % hud.intent_label.text)
	var ctx: ViewCtx = screen.view.ctx
	_check(ctx.boss != null and not ctx.boss_intent.is_empty() and BossOverlay.attack_of(ctx).get("id", "") == "LAY_EGGS", "view context reads the intent and its attack")
	var mark: Dictionary = (intent["targets"] as Array)[0]
	var victim: SimFighter = null
	for f in sim.fighters:
		if f.id == int(mark["id"]):
			victim = f
	_check(not BossOverlay.is_dodged(mark, victim, 90.0), "marked caterpillar in place: not dodged")
	victim.x += 200.0
	_check(BossOverlay.is_dodged(mark, victim, 90.0), "marked caterpillar moved away: dodged (greyed)")
	victim.x -= 200.0
	victim.hidden = true
	_check(BossOverlay.is_dodged(mark, victim, 90.0), "marked caterpillar hidden: dodged")
	victim.hidden = false
	# status icons
	SimStatus.apply(sim, victim, "PARASITE", 3)
	await _frames(3)
	_check(victim.statuses.has("PARASITE") and screen.view.ctx.fighters.has(victim), "PARASITE on a fighter is visible to the view")
	# vulnerable look
	SimBoss.set_state(sim, "RESTING")
	await _frames(3)
	_check(hud.tag_label.text != "" and hud.bar.vulnerable and screen.view.ctx.boss_vulnerable, "RESTING shows the VULNERABLE tag")
	# phase change
	sim.boss.hp = 80
	SimBoss.on_damaged(sim, sim.boss)
	await _frames(3)
	_check(hud.shown_phase == 2 and hud.bar.phase == 2, "phase change reaches the HUD (phase 2)")
	_check(not screen.view.boss_fx.rings.is_empty(), "phase change spawns rings")
	# defeat
	sim.boss.hp = 0
	sim.boss.alive = false
	SimBoss.on_damaged(sim, sim.boss)
	await _frames(3)
	_check(not screen.view.boss_fx.confetti.is_empty(), "defeat spawns confetti")
	var n: int = 0
	while screen.story_end_timer < 0.0 and n < 400:
		await _frames(1)
		n += 1
	_check(screen.story_end_timer >= 0.0 and bool(GameState.story_result.get("won", false)) and str(GameState.story_result.get("reason", "")) == "BOSS_DEFEATED", "defeat ends the level as a win (BOSS_DEFEATED)")
	screen.story_end_timer = 0.01
	await _frames(4)
	_check(routed.has("story_results"), "defeat routes to the results screen")
	screen.queue_free()
	await _frames(2)
	await _run_results()


func _run_results() -> void:
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = func(_s: String) -> void: pass
	add_child(res)
	await _frames(3)
	_check(res.get_child_count() > 1, "results screen builds for the boss win")
	res.queue_free()
	await _frames(1)


func _run_cuca(id: String) -> void:
	var screen: CombatScreen = _screen(id)
	await _frames(20)
	var sim: CombatSim = screen.sim as CombatSim
	_check(sim != null and screen.t_now > 0.0, "%s: CombatScreen runs frames" % id)
	var kinds: Array[String] = []
	for f in sim.fighters:
		if not kinds.has(f.kind):
			kinds.append(f.kind)
	var has_larva: bool = kinds.any(func(k: String) -> bool: return k.begins_with("LARVA_L"))
	_check(has_larva and sim.fighters.filter(func(f: SimFighter) -> bool: return f.team == 0).size() == 4, "%s: four story larvae (%s)" % [id, str(kinds)])
	if id == "cuca_boss":
		_check(_boss_hud(screen) != null and _boss_hud(screen).visible, "cuca_boss: boss bar visible")
		for st in ["idle", "approach", "warn", "dive", "return", "rest", "fall"]:
			sim.boss.ai_state = st
			sim.boss.flying = st != "rest" and st != "fall"
			await _frames(2)
		SimBoss.set_state(sim, "PERCHED")
		screen.view.ctx.read_sim(sim, 0.0)
		_check(screen.view.ctx.boss_vulnerable, "cuca_boss: PERCHED is vulnerable in the view")
	else:
		_check(_boss_hud(screen) != null and not _boss_hud(screen).visible, "%s: boss bar hidden without a boss" % id)
	if kinds.has("GREAT_TIT"):
		for st in ["idle", "warn", "dive", "fall"]:
			for f in sim.fighters:
				if f.kind == "GREAT_TIT":
					f.ai_state = st
					f.flying = st != "idle" and st != "fall"
			await _frames(2)
	screen.queue_free()
	await _frames(2)


func _run_map_and_intro() -> void:
	_check(LarvaArt.instar("LARVA_L3") == "L3" and LarvaArt.instar("LARVA_L5") == "L5" and LarvaArt.instar("LARVA_L1") == "L1", "LarvaArt picks the instar look")
	StoryProgress.reset_progress()
	for id in ["egg_1", "egg_2", "egg_3", "egg_4", "egg_boss", "larva_1", "larva_2", "larva_3", "larva_4", "larva_5"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 1})
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = func(_s: String) -> void: pass
	add_child(map)
	await _frames(3)
	_check(map.open_stage == "LARVA_EARLY" and map.find_child("Level_larva_boss", true, false) != null, "map: larva_boss is a real node")
	_check(StoryProgress.is_unlocked(_level("larva_boss")) and not StoryProgress.is_unlocked(_level("cuca_1")), "cuca_1 is locked until larva_boss is won")
	StoryProgress.record_result({"level_id": "larva_boss", "won": true, "stars": 2})
	map.open_stage = "LARVA"
	map._build()
	await _frames(3)
	_check(map.level_nodes.size() == 7, "map: the Cuca stage shows 6 nodes plus the boss (%d)" % map.level_nodes.size())
	_check(map.find_child("Level_cuca_boss", true, false) != null and StoryProgress.is_unlocked(_level("cuca_1")), "map: cuca_boss node exists and cuca_1 opens after larva_boss")
	map.queue_free()
	await _frames(1)
	GameState.story_level = _level("larva_boss")
	var intro: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	add_child(intro)
	await _frames(3)
	var texts: Array[String] = []
	_collect_labels(intro, texts)
	var joined: String = "\n".join(texts)
	_check(joined.contains(tr("BOSS_TACHINID_NAME")) and joined.contains(tr("BOSS_TACHINID_FACT")) and joined.contains(tr("BOSS_TACHINID_ATTACKS")), "intro card shows the boss name, a biology line and the attacks hint")
	intro.queue_free()
	await _frames(1)


func _collect_labels(n: Node, out: Array[String]) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_labels(c, out)
