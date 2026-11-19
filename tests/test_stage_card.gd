## Stage card: shown once per stage before the level card, reopened by the "?" of the map, every stage has all its texts, flows on.
##   godot --headless --path . res://tests/TestStageCard.tscn
extends Node

var failures: int = 0
var _went: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _on_go(screen_name: String) -> void:
	_went.append(screen_name)


func _ready() -> void:
	var old_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://stage_card_test.cfg"
	StoryProgress.reset_progress()
	_test_texts()
	await _test_flow()
	await _test_help()
	_test_save()
	await _test_layouts()
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = old_path
	GameState.story_level = null
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _missing(key: String) -> bool:
	return tr(key) == key or tr(key).is_empty()


func _test_texts() -> void:
	for lang: String in ["en", "ca"]:
		TranslationServer.set_locale(lang)
		var bad: Array[String] = []
		for stage in StoryUi.STAGES:
			for key in StageCard.text_keys(stage):
				if _missing(key):
					bad.append(key)
			var entries: Array[Dictionary] = StageCard.controls(stage)
			if entries.is_empty():
				bad.append(stage + " controls")
			for entry in entries:
				if _missing(entry["cap"]):
					bad.append(entry["cap"])
				for chip: Array in entry["chips"]:
					if chip[1] != "" and _missing(chip[1]):
						bad.append(chip[1])
		for key in ["STAGECARD_KICKER", "STAGECARD_LABEL_GOAL", "STAGECARD_LABEL_CONTROLS", "STAGECARD_LABEL_KEYS", "STAGECARD_LABEL_TIPS", "STAGECARD_BTN_OK", "STAGECARD_HELP_TOOLTIP"]:
			if _missing(key):
				bad.append(key)
		_check(bad.is_empty(), "[%s] every stage has all its texts, captions and button labels %s" % [lang, bad])
	TranslationServer.set_locale("en")
	_check(StoryUi.STAGES.size() == 7, "seven stages")
	_check(StageCard.controls("PUPA")[0]["chips"].size() == 4, "the digging stage shows the four arrows")


func _make_map() -> Control:
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = _on_go
	add_child(map)
	return map


func _test_flow() -> void:
	var levels: Array[LevelDef] = StoryProgress.levels()
	var map: Control = _make_map()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not StoryProgress.stage_intro_seen("EGG"), "a new save has seen no stage card")
	_went.clear()
	map.level_nodes[0].press()
	_check(_went == ["stage_card"] and GameState.story_level == levels[0], "the first open of a stage goes to its stage card")
	map.queue_free()
	var card: Control = (load("res://ui/story/StageCard.tscn") as PackedScene).instantiate()
	card.go_callable = _on_go
	add_child(card)
	await get_tree().process_frame
	_check(card.stage == "EGG" and card.ok_button != null and card.back_button != null, "the card explains the stage of the level and has Got it and Back")
	_check(StoryProgress.stage_intro_seen("EGG"), "showing the card marks the stage as seen")
	_went.clear()
	card.ok_button.pressed.emit()
	_check(_went == ["level_intro"] and GameState.story_level == levels[0], "Got it continues to the level card")
	_went.clear()
	card.back_button.pressed.emit()
	_check(_went == ["story_map"], "Back goes to the map")
	card.queue_free()
	map = _make_map()
	await get_tree().process_frame
	await get_tree().process_frame
	_went.clear()
	map.level_nodes[0].press()
	_check(_went == ["level_intro"], "the second open of the same stage goes straight to the level card")
	map.queue_free()


func _test_help() -> void:
	var map: Control = _make_map()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(map.help_button != null, "the map has a ? button for the open stage")
	_went.clear()
	map.help_button.pressed.emit()
	_check(_went == ["stage_card"], "? opens the stage card again")
	map.queue_free()
	var card: Control = (load("res://ui/story/StageCard.tscn") as PackedScene).instantiate()
	card.go_callable = _on_go
	add_child(card)
	await get_tree().process_frame
	_check(card.stage == "EGG" and card.back_button == null, "opened from the map it shows the open stage and no Back button")
	_went.clear()
	card.ok_button.pressed.emit()
	_check(_went == ["story_map"], "Got it closes to the map when opened with ?")
	card.queue_free()
	StageCard.request("", false)


func _test_save() -> void:
	StoryProgress.mark_stage_intro_seen("NEST")
	StoryProgress.load_progress()
	_check(StoryProgress.stage_intro_seen("NEST") and StoryProgress.stage_intro_seen("EGG") and not StoryProgress.stage_intro_seen("MOTH"), "seen stage cards survive a save/load round trip")
	StoryProgress.reset_progress()
	_check(not StoryProgress.stage_intro_seen("EGG"), "reset forgets the seen cards")


## Every stage builds at a phone and a desktop size, with the content inside its scroll area (no scrolling needed).
func _test_layouts() -> void:
	var win: Window = get_window()
	var old_size: Vector2i = win.size
	TouchMetrics.force_dpi = 440.0
	TouchMetrics.force = 1
	for sz: Vector2i in [Vector2i(2000, 900), Vector2i(1280, 720)]:
		win.size = sz
		for i in 4:
			await get_tree().process_frame
		for stage in StoryUi.STAGES:
			GameState.story_level = null
			for level in StoryProgress.levels():
				if level.stage == stage:
					GameState.story_level = level
					break
			StageCard.request(stage, true)
			var card: Control = (load("res://ui/story/StageCard.tscn") as PackedScene).instantiate()
			card.go_callable = _on_go
			add_child(card)
			var last_fit: float = -1.0
			for i in 40:
				await get_tree().process_frame
				if i > 5 and is_equal_approx(card._fit, last_fit) and card._scroll.size.y > 0.0:
					break
				last_fit = card._fit
			var scroll: ScrollContainer = card._scroll
			var content: Control = scroll.get_child(0)
			_check(content.get_combined_minimum_size().y <= scroll.size.y + 1.0, "%s fits without scrolling at %s (%.0f of %.0f)" % [stage, sz, content.get_combined_minimum_size().y, scroll.size.y])
			card.queue_free()
			await get_tree().process_frame
	TouchMetrics.force = -1
	TouchMetrics.force_dpi = 0.0
	win.size = old_size
	StageCard.request("", false)
