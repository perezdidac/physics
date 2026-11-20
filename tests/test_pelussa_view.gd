## Pelussa stage view: each larva level on the real CombatScreen (larva and blue tit art, objective widget by rule, merged arsenal with the
## "NEW!" badge, wave banner), the level intro card and the story map with the Pelussa nodes and the boss node.
##   godot --headless --path . res://tests/TestPelussaView.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	StoryProgress.save_path = "user://pelussa_view_test.cfg"
	StoryProgress.reset_progress()
	await _run()
	StoryProgress.reset_progress()
	GameState.story_level = null
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hud(screen: CombatScreen, script_class: Variant) -> Node:
	for h in screen.huds:
		if is_instance_of(h, script_class):
			return h
	return null


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id) as LevelDef


func _run() -> void:
	for id in ["larva_1", "larva_2", "larva_3", "larva_4", "larva_5"]:
		await _run_level(id)
	await _run_arsenal()
	await _run_intro_and_map()


func _run_level(id: String) -> void:
	GameState.story_level = _level(id)
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	add_child(screen)
	await _frames(20)
	var sim: CombatSim = screen.sim as CombatSim
	_check(sim != null and sim.level != null and screen.t_now > 0.0, "%s: CombatScreen runs frames" % id)
	var kinds: Array[String] = []
	for f in sim.fighters:
		if not kinds.has(f.kind):
			kinds.append(f.kind)
	var top: TopHud = _hud(screen, TopHud) as TopHud
	_check(top.objective_panel.visible and not top.objective_label.text.begins_with("HUD_"), "%s: objective widget (%s)" % [id, top.objective_label.text])
	var rule: String = sim.level.win_rule
	if rule == "WAVES":
		_check(top.objective_label.text.contains(str(sim.waves_left)), "%s: WAVES objective shows waves_left" % id)
		top.show_wave_banner(1)
		await _frames(3)
		_check(top.wave_banner.visible, "%s: wave banner shows" % id)
		_check(screen.view.ctx.has_anthill, "%s: view reads the anthill" % id)
	elif rule == "ELIMINATE":
		_check(top.objective_label.text.contains(str(sim.enemies_alive)), "%s: ELIMINATE objective shows enemies_alive" % id)
	else:
		# REACH, RESCUE, SURVIVE_ROUNDS with hiding spots: their own objective lines (tests/test_story_rules2.gd checks the texts)
		_check(not top.objective_label.text.is_empty() and not top.objective_label.text.contains("Enemies"), "%s: %s objective line (%s)" % [id, rule, top.objective_label.text])
	if kinds.has("BLUE_TIT"):
		for st in ["idle", "approach", "warn", "dive", "return", "fall"]:
			for f in sim.fighters:
				if f.kind == "BLUE_TIT":
					f.ai_state = st
					f.flying = st != "idle" and st != "fall"
					f.grounded = f.grounded and st != "fall" # a bird in the air, not on the ground, is the one that falls
			await _frames(1 if st == "fall" else 3) # a falling bird may drown within a few frames when its level has water below it
		_check(BirdArt.state(_first_of(sim, "BLUE_TIT")) == BirdArt.FALL, "%s: blue tit poses draw (fall last)" % id)
	_check(kinds.has("LARVA_L1") or kinds.has("LARVA_L2"), "%s: larvae drawn (%s)" % [id, str(kinds)])
	screen.queue_free()
	await _frames(2)


func _first_of(sim: CombatSim, kind: String) -> SimFighter:
	for f in sim.fighters:
		if f.kind == kind:
			return f
	return null


func _run_arsenal() -> void:
	StoryProgress.record_result({"level_id": "larva_1", "won": true, "stars": 1})
	StoryProgress.record_result({"level_id": "larva_2", "won": true, "stars": 1})
	GameState.story_level = _level("larva_3")
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	add_child(screen)
	await _frames(15)
	var bottom: BottomHud = _hud(screen, BottomHud) as BottomHud
	var ids: Array[String] = []
	for i in bottom.arsenal():
		ids.append(HudWeapons.id_of(i))
	_check(ids.has("URTICARIA") and ids.has("FUET"), "weapon bar shows the merged arsenal (%s)" % str(ids))
	var fuet: int = ids.find("FUET")
	_check(fuet >= 0 and bottom.slots[HudWeapons.index_of_id("FUET")].is_new and not bottom.slots[HudWeapons.index_of_id("URTICARIA")].is_new, "FUET carries the NEW badge, URTICARIA does not")
	bottom.select_weapon(HudWeapons.index_of_id("FUET"), false)
	bottom.rebuild_weapon_bar()
	_check(bottom._new_chip.visible, "NEW chip beside the active weapon")
	_check(HudWeapons.icon(HudWeapons.index_of_id("PICOTADA")) != null, "PICOTADA has an icon")
	screen.queue_free()
	await _frames(2)


func _run_intro_and_map() -> void:
	var intro: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	GameState.story_level = _level("larva_4")
	add_child(intro)
	await _frames(2)
	_check(intro.enemies_text().count("×") == 2, "intro lists the mixed enemies (%s)" % intro.enemies_text())
	_check(intro.abilities_text() != "" and intro.weapons_text().contains(StoryUi.weapon_name("URTICARIA")), "intro shows weapons and abilities")
	intro.queue_free()
	StoryProgress.reset_progress()
	for id in ["egg_1", "egg_2", "egg_3", "egg_4", "egg_boss"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 1})
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = func(_s: String) -> void: pass
	add_child(map)
	await _frames(3)
	_check(map.open_stage == "LARVA_EARLY" and map.level_nodes.size() == 6, "map opens the Pelussa stage with 6 level nodes (5 levels + the boss)")
	_check(map.find_child("Level_larva_boss", true, false) != null, "map shows the real boss node (larva_boss)")
	_check(StoryProgress.is_unlocked(StoryProgress.levels()[5]), "larva_1 is open after egg_boss")
	map.queue_free()
