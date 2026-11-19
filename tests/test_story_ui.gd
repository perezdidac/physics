## Story-mode UI: boot entry, StoryProgress save, GameState level config, and the three story screens.
##   godot --headless --path . res://tests/TestStoryUi.tscn
extends Node

var failures: int = 0
var _went: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _on_go(screen_name: String) -> void:
	_went.append(screen_name)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _ready() -> void:
	_test_progress()
	_test_game_state()
	await _test_boot()
	await _test_map()
	await _test_intro()
	await _test_results()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_progress() -> void:
	var old_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://story_test.cfg"
	StoryProgress.reset_progress()
	var lv: Array[LevelDef] = StoryProgress.levels()
	_check(lv.size() >= 3, "level list has the egg levels")
	_check(StoryProgress.is_unlocked(lv[0]), "first level is unlocked")
	_check(not StoryProgress.is_unlocked(lv[1]), "second level is locked at first")
	_check(not StoryProgress.is_unlocked(lv[2]), "a level that is not playable stays locked")
	StoryProgress.record_result({"level_id": lv[0].id, "won": false, "stars": 0})
	_check(not StoryProgress.is_unlocked(lv[1]), "a lost level unlocks nothing")
	StoryProgress.record_result({"level_id": lv[0].id, "won": true, "stars": 2})
	_check(StoryProgress.stars(lv[0].id) == 2 and StoryProgress.is_unlocked(lv[1]), "winning stores stars and unlocks the next level")
	StoryProgress.record_result({"level_id": lv[0].id, "won": true, "stars": 1})
	_check(StoryProgress.stars(lv[0].id) == 2, "a worse result keeps the best stars")
	_check(StoryProgress.unlocked_weapons().has("EMPENTA") == lv[0].unlocks.has("EMPENTA"), "unlocked weapons follow the won levels")
	StoryProgress.load_progress()
	_check(StoryProgress.stars(lv[0].id) == 2, "stars survive a save/load round trip")
	StoryProgress.reset_progress()
	_check(StoryProgress.stars(lv[0].id) == 0, "reset clears the stars")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = old_path


func _test_game_state() -> void:
	var lv: Array[LevelDef] = StoryProgress.levels()
	GameState.story_level = lv[0]
	var cfg: Variant = GameState.make_match_config()
	_check(cfg.level == lv[0], "make_match_config fills cfg.level")
	_check(cfg.map_idx == lv[0].map_idx and cfg.seed == lv[0].seed and cfg.game_mode == "1P_CPU", "cfg takes map, seed and mode from the level")
	_check(cfg.worms_per_team == lv[0].player_names.size() and cfg.team_names[0] == lv[0].player_names, "cfg takes the player squad from the level")
	_check(cfg.ai_difficulty == lv[0].ai_difficulty, "cfg takes the difficulty from the level")
	GameState.prepare_quick_match("1P_CPU")
	_check(GameState.story_level == null, "quick match resets story_level")
	cfg = GameState.make_match_config()
	_check(cfg.level == null, "classic config has no level")
	GameState.story_level = lv[0]


func _test_boot() -> void:
	var boot: Control = (load("res://ui/menus/Boot.tscn") as PackedScene).instantiate()
	boot.go_callable = _on_go
	add_child(boot)
	await get_tree().process_frame
	_check(boot.MENU_KEYS[0][0] == "MENU_STORY_TITLE", "STORY is the first menu entry")
	_went.clear()
	boot._unhandled_input(_key(KEY_ENTER))
	_check(_went == ["story_map"], "Enter on the cursor (STORY) goes to story_map")
	boot.queue_free()


func _test_map() -> void:
	StoryProgress.save_path = "user://story_test.cfg"
	StoryProgress.reset_progress()
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = _on_go
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(map.stage_chips.size() == 7, "map shows the 7 stages")
	_check(map.level_nodes.size() == StoryProgress.levels().filter(func(l: LevelDef) -> bool: return l.stage == map.open_stage).size(), "map shows a node per level of the open stage")
	_check(map.level_nodes[0].focus_mode != Control.FOCUS_NONE and map.level_nodes[1].focus_mode == Control.FOCUS_NONE, "only unlocked levels take focus")
	_went.clear()
	map.level_nodes[1].press()
	_check(_went.is_empty(), "a locked level cannot be opened")
	StoryProgress.mark_stage_intro_seen("EGG") # the stage card is covered by TestStageCard
	map.level_nodes[0].press()
	_check(_went == ["level_intro"] and GameState.story_level == StoryProgress.levels()[0], "opening a level sets story_level and goes to level_intro")
	_went.clear()
	map._unhandled_input(_key(KEY_ESCAPE))
	_check(_went == ["boot"], "Esc goes back to boot")
	map.queue_free()


func _test_intro() -> void:
	GameState.story_level = StoryProgress.levels()[0]
	var card: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	card.go_callable = _on_go
	add_child(card)
	await get_tree().process_frame
	_check(card.play_button != null and card.back_button != null, "level card has Play and Back")
	var platform: bool = card.level.mode == "PLATFORM"
	_check(card.enemies_text().contains("2"), "level card lists the enemy count")
	_check(card.weapons_text() == tr("PLAT_NO_WEAPONS" if platform else "STORY_NO_WEAPONS"), "level 1 has no weapons")
	_went.clear()
	card.play()
	_check(_went == ["platform" if platform else "combat"] and GameState.story_level == card.level, "Play goes to the level's screen with the level set")
	_went.clear()
	card.back_button.pressed.emit()
	_check(_went == ["story_map"], "Back goes to the map")
	card.queue_free()


func _test_results() -> void:
	var level: LevelDef = StoryProgress.levels()[0]
	GameState.story_result = {"level_id": level.id, "won": true, "survivors": 3, "stars": 3, "reason": "SURVIVED"}
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = _on_go
	add_child(res)
	await get_tree().process_frame
	_check(StoryProgress.stars(level.id) == 3, "results records the stars")
	_went.clear()
	res.retry_button.pressed.emit()
	_check(_went == ["level_intro"] and GameState.story_level == level, "Retry goes to the same level card")
	_went.clear()
	res.continue_button.press()
	_check(_went == ["story_map"], "Continue goes to the map")
	res.queue_free()
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	GameState.story_result = {}
	GameState.story_level = null
