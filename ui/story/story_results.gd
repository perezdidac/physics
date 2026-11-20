## Results of a story match (from GameState.story_result): won or lost, stars, survivors, reason, the silk reward, unlocked weapons.
## Every story level ends here (combat, nest, convoy and the platform levels of the egg, pupa and moth), so this is where silk is recorded.
extends Control

const SilkIcon := preload("res://ui/story/nest_hub.gd").SilkIcon
## Count-up of the silk chip: wait, then count for this long (seconds).
const SILK_COUNT_DELAY := 0.35
const SILK_COUNT_TIME := 0.9

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var stats: Dictionary = {}
var level: LevelDef
var continue_button: ChamferButton
var retry_button: Button
## Opens El Bolsó (shown when the level gave silk to spend).
var hub_button: Button
## Silk the result just earned (what the new best is worth minus the old best; 0 on a replay that beats nothing).
var silk_earned: int = 0
## Best stars of the level before this result.
var best_before: int = 0
## The silk chip ("+N silk"), its count-up label and the line under it (breakdown, or why no silk was earned).
var silk_chip: Control
var silk_label: Label
var silk_note: Label
## Silk shown by the count-up so far; it runs once per screen (a resize shows the final number).
var silk_shown: float = 0.0
var _silk_counted: bool = false


func _ready() -> void:
	theme = UiUtil.get_theme()
	stats = GameState.story_result
	level = StoryUi.find_level(str(stats.get("level_id", "")))
	if level == null:
		level = GameState.story_level
	if stats.is_empty() or level == null:
		_go.call_deferred("story_map")
		return
	best_before = StoryProgress.stars(level.id)
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
	if won:
		body.add_child(_silk_block(small))
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
	if silk_chip != null and not _silk_counted:
		_silk_counted = true
		_count_silk()


## Parts of the silk just earned: the win, the new stars and the boss bonus (only the new stars on a better replay).
func silk_parts() -> Array[String]:
	var parts: Array[String] = []
	var now: int = StoryProgress.stars(level.id)
	if best_before == 0:
		parts.append(UiUtil.fmt("SILK_PART_WIN", [StoryProgress.SILK_WIN]))
	var new_stars: int = now - best_before
	if new_stars > 0:
		parts.append(UiUtil.fmt("SILK_PART_STARS", [new_stars, new_stars * StoryProgress.SILK_PER_STAR]))
	if best_before == 0 and StoryProgress.is_boss_level(level.id):
		parts.append(UiUtil.fmt("SILK_PART_BOSS", [StoryProgress.SILK_BOSS]))
	return parts


## The silk reward of a won level: a gold chip "+N silk" with the silk now in the pouch, and the breakdown under it; on a replay that
## beats nothing, a line saying the stars were already won (and the best to beat).
func _silk_block(small: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	silk_chip = null
	if silk_earned <= 0:
		var why: String = tr("STORY_RESULT_SILK_NONE")
		if best_before < 3:
			why += " " + UiUtil.fmt("STORY_RESULT_SILK_BEST", [best_before])
		silk_note = StoryUi.paragraph(why, 13, Palette.IVORY_HINT)
		box.add_child(silk_note)
		return box
	var chip := PanelContainer.new()
	chip.name = "SilkChip"
	chip.theme_type_variation = "PillPanel"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var icon: Control = SilkIcon.new()
	icon.custom_minimum_size = Vector2(26, 26) if small else Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	silk_label = UiUtil.label(UiUtil.fmt("STORY_RESULT_SILK_GAIN", [int(silk_shown) if not _silk_counted else silk_earned]), "TitleBlackLabel", 20 if small else 26, Palette.BRASS_BRIGHT)
	row.add_child(silk_label)
	var total: Label = UiUtil.label(UiUtil.fmt("STORY_RESULT_SILK_TOTAL", [StoryProgress.silk()]), "BodyBoldLabel", 12 if small else 14, Palette.IVORY)
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(total)
	box.add_child(chip)
	silk_chip = chip
	silk_note = StoryUi.paragraph(" · ".join(silk_parts()), 12, Palette.IVORY_HINT)
	box.add_child(silk_note)
	return box


## Counts the chip up from 0 to the silk earned, then a pickup sound and a little pop.
func _count_silk() -> void:
	silk_shown = 0.0
	var tw := create_tween()
	tw.tween_interval(SILK_COUNT_DELAY)
	tw.tween_method(_show_silk, 0.0, float(silk_earned), SILK_COUNT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_silk_done)


func _show_silk(value: float) -> void:
	silk_shown = value
	if is_instance_valid(silk_label):
		silk_label.text = UiUtil.fmt("STORY_RESULT_SILK_GAIN", [roundi(value)])


func _silk_done() -> void:
	_show_silk(float(silk_earned))
	UiUtil.sfx("crate_pickup")
	if is_instance_valid(silk_chip):
		silk_chip.pivot_offset = silk_chip.size * 0.5
		var pop := create_tween()
		pop.tween_property(silk_chip, "scale", Vector2(1.12, 1.12), 0.08)
		pop.tween_property(silk_chip, "scale", Vector2.ONE, 0.16)
