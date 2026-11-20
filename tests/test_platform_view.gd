## Platformer screen: runs each egg level, HUD hearts and nutrients, keyboard and touch controls, end of level routing, camera,
## and the level card / results screens for platform levels.
##   godot --headless --path . res://tests/TestPlatformView.tscn
extends Node

var failures: int = 0
var routed: Array[String] = []
## Pad that receives the simulated touches (events are fed to its _input, as the viewport would after the stretch transform).
var _pad: PlatformTouchPad


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	TouchMetrics.force = 0 # the pad geometry is checked without the safe insets (the test viewport is tiny)
	await _run()
	TouchMetrics.force = -1
	GameState.story_level = null
	GameState.story_result = {}
	UiUtil.touch_seen = false
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _on_go(screen_name: String) -> void:
	routed.append(screen_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(screen: PlatformScreen, n: int) -> void:
	for i in n:
		screen.tick(1.0 / 60.0)


func _make(level_idx: Variant) -> PlatformScreen:
	var screen: PlatformScreen = load("res://platform/PlatformScreen.tscn").instantiate() as PlatformScreen
	screen.auto_start = false
	screen.go_callable = _on_go
	add_child(screen)
	screen.start(load("res://data/levels/egg_%s.tres" % str(level_idx)) as LevelDef)
	return screen


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_pad._input(e)


func _run() -> void:
	for i in [1, 2, 3, 4]:
		await _test_level(i)
	await _test_storm()
	await _test_boss()
	await _test_hatched()
	await _test_story_map()
	await _test_touch()
	await _test_end_and_pause()
	await _test_story_screens()


func _test_level(idx: int) -> void:
	var screen: PlatformScreen = _make(idx)
	await _frames(3)
	_check(screen.sim != null and screen.layout != null and screen.level.mode == "PLATFORM", "egg %d: screen owns a sim and a layout" % idx)
	_check(screen.actors.size() == screen.layout.ants.size() + 1, "egg %d: one view per ant plus the player" % idx)
	_ticks(screen, 120)
	_check(screen.sim.time > 1.9, "egg %d: fixed-step loop advanced the sim (%.2f s)" % [idx, screen.sim.time])
	_check(screen.hud.status.hearts == screen.sim.player.hearts and screen.hud.status.max_hearts == 3, "egg %d: HUD shows the hearts (%d)" % [idx, screen.hud.status.hearts])
	_check(screen.hud.status.nutrient_text() == "0/%d" % screen.layout.nutrients.size(), "egg %d: HUD shows nutrients N/M (%s)" % [idx, screen.hud.status.nutrient_text()])
	var vs: Vector2 = screen.get_viewport().get_visible_rect().size
	var half: Vector2 = vs / (2.0 * screen.cam.zoom)
	_check(screen.cam.pos.x >= half.x - 0.5 and screen.cam.pos.x <= screen.layout.size.x - half.x + 0.5, "egg %d: camera stays inside the world" % idx)
	# nutrient pickup updates the HUD and spawns a sparkle
	screen.sim.player.pos = screen.layout.nutrients[0]
	_ticks(screen, 3)
	_check(screen.hud.status.nutrients == 1 and screen.hud.status.nutrient_text().begins_with("1/"), "egg %d: taking a nutrient updates the HUD" % idx)
	_check(screen.fx.live_count() > 0, "egg %d: pickup spawns sparkles and a floating text" % idx)
	await _frames(2)
	screen.queue_free()
	await _frames(1)


func _test_touch() -> void:
	var screen: PlatformScreen = _make(1)
	screen.hud.pad.force_show = true
	await _frames(3)
	var pad: PlatformTouchPad = screen.hud.pad
	_pad = pad
	var vs: Vector2 = pad.size
	_check(pad.is_shown() and vs.x > 0.0, "touch pad is shown on a touch device")
	_check(pad.left_rect().size.x >= 64.0 and pad.jump_rect().size.x >= 64.0, "touch buttons are big (%d / %d px)" % [pad.left_rect().size.x, pad.jump_rect().size.x])
	_check(pad.left_rect().position.x < vs.x * 0.5 and pad.jump_rect().position.x > vs.x * 0.5, "arrows bottom left, JUMP bottom right")
	_ticks(screen, 90)
	var x0: float = screen.sim.player.pos.x
	_touch(0, pad.right_rect().get_center(), true)
	await _frames(1)
	_check(pad.right() and not pad.left(), "touch on the right arrow is held")
	_ticks(screen, 40)
	_check(screen.sim.player.pos.x > x0 + 30.0, "holding the right arrow moves the egg (%.0f -> %.0f)" % [x0, screen.sim.player.pos.x])
	# multi-touch: second finger taps JUMP while the first holds right
	_check(screen.sim.player.on_ground, "egg is on the ground before the jump")
	var y0: float = screen.sim.player.pos.y
	_touch(1, pad.jump_rect().get_center(), true)
	await _frames(1)
	_check(pad.right() and pad.jump(), "right and JUMP held at the same time (multi-touch)")
	_ticks(screen, 8)
	_check(screen.sim.player.pos.y < y0 - 10.0, "JUMP while holding right makes the egg jump (%.0f -> %.0f)" % [y0, screen.sim.player.pos.y])
	_touch(1, pad.jump_rect().get_center(), false)
	_touch(0, pad.right_rect().get_center(), false)
	await _frames(1)
	_check(not pad.right() and not pad.jump() and not pad.left(), "releasing the fingers releases the controls")
	# slide a finger from right to left arrow
	_touch(2, pad.right_rect().get_center(), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = pad.left_rect().get_center()
	pad._input(drag)
	await _frames(1)
	_check(pad.left() and not pad.right(), "sliding the finger to the left arrow switches direction")
	_touch(2, drag.position, false)
	# a tap shorter than a frame still jumps (latch)
	_ticks(screen, 120)
	var y1: float = screen.sim.player.pos.y
	_touch(3, pad.jump_rect().get_center(), true)
	_touch(3, pad.jump_rect().get_center(), false)
	await _frames(1)
	_ticks(screen, 6)
	_check(screen.sim.player.pos.y < y1 - 5.0, "a very short JUMP tap still jumps")
	screen.queue_free()
	await _frames(1)


func _test_end_and_pause() -> void:
	var screen: PlatformScreen = _make(1)
	await _frames(2)
	routed.clear()
	screen.set_paused(true)
	var t0: float = screen.sim.time
	_ticks(screen, 30)
	_check(screen.hud.pause_panel.visible and is_equal_approx(screen.sim.time, t0), "pause stops the sim and shows the menu")
	screen.hud.exit_button.pressed.emit()
	_check(routed == ["story_map"], "Exit button goes to the story map")
	screen.set_paused(false)
	_check(not screen.hud.pause_panel.visible, "resume hides the menu")
	# level end routes to the results after ~1.5 s
	routed.clear()
	var stats: Dictionary = {"level_id": "egg_1", "won": true, "stars": 3, "reason": "REACHED_GOAL", "nutrients": 8, "nutrients_total": 8, "hearts_left": 3, "time": 20.0}
	screen.sim.level_finished.emit(stats)
	_check(GameState.story_result == stats and screen.hud.banner.visible, "level_finished stores the stats and shows the banner")
	_ticks(screen, 60)
	_check(routed.is_empty(), "no routing before the 1.5 s delay")
	_ticks(screen, 50)
	_check(routed == ["story_results"], "level_finished routes to story_results (%s)" % str(routed))
	_ticks(screen, 120)
	_check(routed == ["story_results"], "routes only once")
	screen.queue_free()
	await _frames(1)
	# real win through the sim: stand in the goal
	var screen2: PlatformScreen = _make(1)
	await _frames(2)
	routed.clear()
	screen2.sim.player.pos = screen2.layout.goal.get_center()
	_ticks(screen2, 200)
	_check(screen2.ended and bool(GameState.story_result.get("won", false)) and routed == ["story_results"], "reaching the goal ends the level and routes to the results")
	screen2.queue_free()
	await _frames(1)


func _test_story_screens() -> void:
	var level: LevelDef = load("res://data/levels/egg_1.tres") as LevelDef
	GameState.story_level = level
	var card: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	card.go_callable = _on_go
	add_child(card)
	await _frames(2)
	routed.clear()
	card.play()
	_check(routed == ["platform"], "LevelIntro routes a PLATFORM level to the platform screen")
	card.queue_free()
	var combat_level: LevelDef = level.duplicate() as LevelDef
	combat_level.mode = "COMBAT"
	GameState.story_level = combat_level
	var card2: Control = (load("res://ui/story/LevelIntro.tscn") as PackedScene).instantiate()
	card2.go_callable = _on_go
	add_child(card2)
	await _frames(2)
	routed.clear()
	card2.play()
	_check(routed == ["combat"], "LevelIntro routes a COMBAT level to combat")
	card2.queue_free()
	var old_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://platform_view_test.cfg"
	StoryProgress.reset_progress()
	GameState.story_result = {"level_id": level.id, "won": true, "stars": 2, "reason": "REACHED_GOAL", "nutrients": 5, "nutrients_total": 8, "hearts_left": 2, "time": 30.0}
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = _on_go
	add_child(res)
	await _frames(2)
	var texts: Array[String] = []
	_collect_labels(res, texts)
	var joined: String = "\n".join(texts)
	_check(joined.contains("5") and joined.contains(tr("PLAT_RESULT_NUTRIENTS").get_slice("%", 0)), "results show nutrients N of M for a platform level")
	_check(joined.contains(tr("PLAT_RESULT_HEARTS").get_slice("%", 0)), "results show the hearts left")
	_check(not joined.contains(tr("STORY_RESULT_SURVIVORS").get_slice("%", 0)), "results do not show survivors for a platform level")
	_check(joined.contains(tr("PLAT_REASON_REACHED_GOAL")), "results show the REACHED_GOAL text")
	res.queue_free()
	GameState.story_result = {"level_id": level.id, "won": false, "stars": 0, "reason": "LOST", "nutrients": 0, "nutrients_total": 8, "hearts_left": 0, "time": 30.0}
	var res2: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res2.go_callable = _on_go
	add_child(res2)
	await _frames(2)
	var texts2: Array[String] = []
	_collect_labels(res2, texts2)
	_check("\n".join(texts2).contains(res2.reason_text("LOST")) and res2.reason_text("LOST") != "", "results show the LOST text")
	res2.queue_free()
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = old_path
	await _frames(1)


func _collect_labels(node: Node, out: Array[String]) -> void:
	var l := node as Label
	if l != null:
		out.append(l.text)
	for c in node.get_children():
		_collect_labels(c, out)


func _test_storm() -> void:
	var screen: PlatformScreen = _make(4)
	await _frames(3)
	_check(screen.weather.storm and screen.backdrop.storm > 0.5, "egg 4: storm weather and a darker sky")
	_check(screen.boss_view.boss == null and not screen.hud.boss_bar.visible, "egg 4: no wasp and no boss bar")
	var gusts: int = 0
	var splashes: int = 0
	var drops_seen: int = 0
	screen.sim.player.pos = screen.layout.wind_zones[0].get_center()
	for i in 900:
		screen.tick(1.0 / 60.0)
		if screen.weather.gusting():
			gusts += 1
		splashes = maxi(splashes, screen.weather.splash_count())
		drops_seen = maxi(drops_seen, screen.sim.drops.size())
	_check(gusts > 0, "egg 4: a wind gust reaches the view (%d frames)" % gusts)
	_check(splashes > 0, "egg 4: rain splashes on the ground (%d)" % splashes)
	_check(drops_seen > 0, "egg 4: the sim's big drops are drawn (%d)" % drops_seen)
	screen.weather.gust(1)
	screen.tick(0.4)
	_check(screen.weather.nudge.length() > 1.0, "a gust nudges the camera (%.1f px)" % screen.weather.nudge.x)
	screen.weather.lightning()
	screen.tick(0.05)
	_check(screen.backdrop.flash > 0.2 and screen.weather.flash > 0.2, "lightning flashes the sky (%.2f)" % screen.backdrop.flash)
	screen.tick(1.0)
	_check(screen.backdrop.flash < 0.05, "the flash dies out")
	await _frames(2)
	screen.queue_free()
	await _frames(1)


func _test_boss() -> void:
	var screen: PlatformScreen = _make("boss")
	await _frames(3)
	_check(screen.sim.boss != null and screen.boss_view.boss == screen.sim.boss and screen.boss_view.visible, "boss level: the wasp has a view")
	_check(screen.hud.intro_banner.visible and screen.hud.intro_banner.text == tr("PLAT_BOSS_INTRO"), "boss level: intro banner '%s'" % screen.hud.intro_banner.text)
	_check(screen.hud.boss_bar.visible and screen.hud.boss_bar.text.contains("60"), "boss bar shows the time (%s)" % screen.hud.boss_bar.text)
	var seen: Dictionary = {}
	var left0: float = screen.sim.time_left
	var marker_seen: bool = false
	for i in 900:
		screen.tick(1.0 / 60.0)
		seen[screen.boss_view.state] = true
		if screen.boss_view.state == "WARN":
			marker_seen = true
		if screen.ended:
			break
	_check(seen.has("WARN") and seen.has("DIVE"), "the wasp view follows WARN and DIVE (%s)" % str(seen.keys()))
	_check(marker_seen and screen.boss_view.target != Vector2.ZERO, "the target marker has a target")
	_check(screen.sim.time_left < left0 - 5.0 and screen.hud.boss_bar.seconds_left < left0 - 5.0, "boss bar counts down (%s)" % screen.hud.boss_bar.text)
	_check(screen.hud.boss_bar.fraction > 0.05, "boss bar fills as the egg gets closer to hatching")
	_check(not screen.hud.intro_banner.visible, "the intro banner goes away")
	screen.sim.tuft_flattened[0] = 5.0
	screen.player_view.position = screen.layout.tufts[0].get_center()
	_ticks(screen, 2)
	await _frames(2)
	_check(screen.world_view.sim.tuft_flattened[0] > 0.0, "a flattened tuft is drawn wilted without errors")
	await _frames(2)
	screen.queue_free()
	await _frames(1)


func _test_hatched() -> void:
	var screen: PlatformScreen = _make("boss")
	await _frames(2)
	routed.clear()
	screen.sim.time = 10.0
	screen.sim.time_left = 0.05
	screen.sim.boss.timer = 99.0
	_ticks(screen, 20)
	_check(screen.ended and str(GameState.story_result.get("reason", "")) == "HATCHED" and bool(GameState.story_result.get("won", false)), "boss: time up ends with HATCHED")
	_check(screen.fx.hatch_t >= 0.0 and not screen.player_view.visible, "boss: the hatching celebration starts and the egg is replaced")
	_check(screen.hud.banner.visible and screen.hud.banner.text == tr("PLAT_BANNER_HATCHED"), "boss: hatched banner")
	_ticks(screen, 120)
	_check(routed.is_empty(), "boss: results wait for the celebration")
	_ticks(screen, 120)
	_check(routed == ["story_results"], "boss: routes to the results after the celebration (%s)" % str(routed))
	screen.queue_free()
	await _frames(1)
	var level: LevelDef = load("res://data/levels/egg_boss.tres") as LevelDef
	var old_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://platform_view_test.cfg"
	StoryProgress.reset_progress()
	GameState.story_result = {"level_id": level.id, "won": true, "stars": 3, "reason": "HATCHED", "nutrients": 0, "nutrients_total": 0, "hearts_left": 3, "time": 60.0}
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = _on_go
	add_child(res)
	await _frames(2)
	var texts: Array[String] = []
	_collect_labels(res, texts)
	var joined: String = "\n".join(texts)
	_check(joined.contains(tr("PLAT_REASON_HATCHED")), "results show the HATCHED text")
	_check(not joined.contains(tr("PLAT_RESULT_NUTRIENTS").get_slice("%", 0)), "results of the boss level have no sap line")
	res.queue_free()
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = old_path
	await _frames(1)


func _test_story_map() -> void:
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = _on_go
	add_child(map)
	await _frames(3)
	var nodes: Array[ChamferButton] = map.level_nodes
	_check(nodes.size() == 5, "story map shows 5 egg nodes (%d)" % nodes.size())
	var crowns: int = 0
	for n in nodes:
		crowns += n.find_children("*", "BossCrown", true, false).size()
	_check(crowns == 1 and nodes.size() == 5 and nodes[4].find_children("*", "BossCrown", true, false).size() == 1, "only the last node has the boss crown")
	_check(nodes.size() == 5 and nodes[4].border_width > nodes[0].border_width, "the boss node has its own frame")
	map.queue_free()
	await _frames(1)
