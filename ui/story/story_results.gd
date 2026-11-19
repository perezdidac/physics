## Results of a story match (from GameState.story_result): won or lost, stars, survivors, reason, unlocked weapons.
extends Control

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var stats: Dictionary = {}
var level: LevelDef
var continue_button: ChamferButton
var retry_button: Button
## Opens El Bolsó (shown when the level gave silk to spend).
var hub_button: Button
## Silk the result just earned (stars won for the first time).
var silk_earned: int = 0


func _ready() -> void:
	theme = UiUtil.get_theme()
	stats = GameState.story_result
	level = StoryUi.find_level(str(stats.get("level_id", "")))
	if level == null:
		level = GameState.story_level
	if stats.is_empty() or level == null:
		_go.call_deferred("story_map")
		return
	silk_earned = StoryProgress.record_result(stats) # once per screen: resizing only rebuilds the widgets
	_build()
	get_viewport().size_changed.connect(_build)


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


## Back to the campaign map.
func continue_story() -> void:
	UiUtil.sfx("tick")
	_go("story_map")


## Goes to the upgrade hub to spend the silk.
func open_hub() -> void:
	UiUtil.sfx("tick")
	_go("nest_hub")


## Text of the end reason: the level mode's own line (digging, flying), the story line, then the platformer line.
func reason_text(reason: String) -> String:
	var keys: Array[String] = []
	if level.mode == "PLATFORM":
		if level.layout != null and level.layout.mode != "":
			keys.append("STORY_REASON_%s_%s" % [level.layout.mode, reason])
		keys.append("STORY_REASON_" + reason)
		keys.append("PLAT_REASON_" + reason)
	else:
		if level.stage == "NEST" or level.stage == "PROCESSION":
			keys.append("STORY_REASON_%s_%s" % [level.stage, reason])
		keys.append("STORY_REASON_" + reason)
	for key in keys:
		var text: String = TranslationServer.translate(key)
		if text != key:
			return text
	return tr(keys[keys.size() - 1])


## Followers that finished in the line: the sim's `followers` count, else the survivors without the leader.
func followers_saved() -> int:
	if stats.has("followers"):
		return int(stats["followers"])
	var survivors: int = int(stats.get("survivors", 0))
	return maxi(0, survivors - 1) if bool(stats.get("won", false)) else 0


## Plays the same level again (through its intro card).
func retry() -> void:
	UiUtil.sfx("tick")
	GameState.story_level = level
	_go("level_intro")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		continue_story()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	var small: bool = StoryUi.is_small(vp)
	var won: bool = bool(stats.get("won", false))
	var parts: Array = StoryUi.make_frame(self, level.map_idx)
	var body: VBoxContainer = parts[1]
	var footer: HBoxContainer = parts[2]
	var kicker: String = "%s · %s" % [tr(level.title_key), UiUtil.fmt("STORY_LEVEL_N", [level.order])]
	body.add_child(StoryUi.make_header(kicker, tr("STORY_RESULT_WON") if won else tr("STORY_RESULT_LOST"), "", null, small))

	var stars := StarRow.new()
	stars.star_size = 30.0 if small else 44.0
	stars.count = int(stats.get("stars", 0))
	stars.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(stars)
	if level.mode == "PLATFORM":
		if int(stats.get("nutrients_total", 0)) > 0:
			body.add_child(StoryUi.paragraph(UiUtil.fmt("PLAT_RESULT_NUTRIENTS", [int(stats.get("nutrients", 0)), int(stats.get("nutrients_total", 0))]), 15))
		body.add_child(StoryUi.paragraph(UiUtil.fmt("PLAT_RESULT_HEARTS", [int(stats.get("hearts_left", 0))]), 15))
	elif level.is_convoy():
		body.add_child(StoryUi.paragraph(UiUtil.fmt("STORY_RESULT_FOLLOWERS", [followers_saved(), maxi(0, level.player_names.size() - 1)]), 15))
	else:
		var survivors: int = int(stats.get("survivors", 0))
		body.add_child(StoryUi.paragraph(UiUtil.fmt("STORY_RESULT_SURVIVORS", [survivors, level.player_names.size()]), 15))
	body.add_child(StoryUi.paragraph(reason_text(str(stats.get("reason", "LOST"))), 13, Palette.IVORY_HINT))
	if won and silk_earned > 0:
		body.add_child(StoryUi.paragraph(UiUtil.fmt("STORY_RESULT_SILK", [silk_earned]), 15, Palette.BRASS_BRIGHT))
	if won and not level.unlocks.is_empty():
		body.add_child(StoryUi.section(tr("STORY_RESULT_UNLOCKED")))
		var names: Array[String] = []
		for id in level.unlocks:
			names.append(StoryUi.weapon_name(id))
		body.add_child(StoryUi.paragraph(", ".join(names), 15, Palette.BRASS_BRIGHT))

	retry_button = StoryUi.cmd_button(tr("STORY_BTN_RETRY"))
	retry_button.pressed.connect(retry)
	footer.add_child(retry_button)
	hub_button = null
	if won and StoryProgress.silk() > 0:
		hub_button = StoryUi.cmd_button(tr("STORY_BTN_HUB"))
		hub_button.pressed.connect(open_hub)
		footer.add_child(hub_button)
	continue_button = StoryUi.deploy_button(tr("STORY_BTN_CONTINUE"))
	continue_button.pressed.connect(continue_story)
	footer.add_child(continue_button)
	TouchMetrics.fit_taps(parts[0], vp, StoryUi.logical(self).y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	continue_button.grab_focus.call_deferred()
