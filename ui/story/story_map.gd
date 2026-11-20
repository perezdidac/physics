## Story campaign map: the strip of all life stages and, for the open stage, the path of its levels.
## Keyboard: Left/Right (or A/D, Up/Down) move between levels, Enter/Space opens one, Esc goes back. Mouse and touch: click/tap.
extends Control

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var back_button: Button
## Opens El Bolsó, the upgrade hub (only built once the NEST stage is unlocked).
var nest_button: Button
## "?" next to the open stage: opens its stage card.
var help_button: Button
## One button per level of the open stage (locked ones included), in campaign order.
var level_nodes: Array[ChamferButton] = []
var stage_chips: Array[ChamferButton] = []
var open_stage: String = "EGG"
var _levels: Array[LevelDef] = []


func _ready() -> void:
	theme = UiUtil.get_theme()
	open_stage = _default_stage()
	_build()
	get_viewport().size_changed.connect(_build)


## The furthest stage that has a playable level: the one the player is in.
func _default_stage() -> String:
	var pick: String = "EGG"
	for level in StoryProgress.levels():
		if StoryProgress.is_unlocked(level) and StoryUi.STAGES.find(level.stage) > StoryUi.STAGES.find(pick):
			pick = level.stage
	return pick


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


## Leaves to the boot screen.
func back_to_menu() -> void:
	UiUtil.sfx("tick")
	_go("boot")


## True once some silk has been earned (any star): El Bolsó (the hub) can be visited, as the results screen also offers it, so the
## platform upgrades matter from the egg stage on.
func nest_unlocked() -> bool:
	return StoryProgress.silk_earned() > 0


## Goes to the upgrade hub.
func open_nest_hub() -> void:
	UiUtil.sfx("tick")
	_go("nest_hub")


## Opens the intro card of `level` when it can be played.
func open_level(level: LevelDef) -> void:
	if not StoryProgress.is_unlocked(level):
		return
	UiUtil.sfx("title_fanfare")
	GameState.story_level = level
	if StoryProgress.stage_intro_seen(level.stage):
		_go("level_intro")
	else:
		StageCard.request(level.stage, false)
		_go("stage_card")


## Opens the stage card (how this stage plays) of the open stage; "Got it!" there comes back to the map.
func open_stage_card() -> void:
	UiUtil.sfx("tick")
	StageCard.request(open_stage, true)
	_go("stage_card")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			back_to_menu()
		KEY_A, KEY_W:
			_step_focus(-1)
		KEY_D, KEY_S:
			_step_focus(1)
		KEY_LEFT, KEY_UP:
			_step_focus(-1)
		KEY_RIGHT, KEY_DOWN:
			_step_focus(1)


## Moves the keyboard focus to the previous/next open level node.
func _step_focus(dir: int) -> void:
	var open: Array[ChamferButton] = []
	for n in level_nodes:
		if n.focus_mode != Control.FOCUS_NONE:
			open.append(n)
	if open.is_empty():
		return
	var cur: int = open.find(get_viewport().gui_get_focus_owner() as ChamferButton)
	open[clampi(cur + dir, 0, open.size() - 1) if cur >= 0 else 0].grab_focus()
	get_viewport().set_input_as_handled()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	level_nodes.clear()
	stage_chips.clear()
	_levels = StoryProgress.levels()
	var vp: Vector2 = get_viewport_rect().size
	var small: bool = StoryUi.is_small(vp)
	var parts: Array = StoryUi.make_frame(self, _levels[0].map_idx if not _levels.is_empty() else 0)
	var body: VBoxContainer = parts[1]
	back_button = StoryUi.cmd_button(tr("STORY_BTN_BACK"))
	back_button.pressed.connect(back_to_menu)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	nest_button = null
	if nest_unlocked():
		nest_button = StoryUi.cmd_button(UiUtil.fmt("STORY_BTN_NEST", [StoryProgress.silk()]))
		nest_button.name = "NestButton"
		nest_button.pressed.connect(open_nest_hub)
		buttons.add_child(nest_button)
	buttons.add_child(back_button)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var title: Label = UiUtil.spaced_label(tr("STORY_TITLE").to_upper(), "TitleBlackLabel", 17 if small else 22, Palette.BRASS_BRIGHT, 2.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	head.add_child(buttons)
	body.add_child(head)
	body.add_child(_build_stage_strip(small))
	body.add_child(_build_stage_detail(small))
	TouchMetrics.fit_taps(parts[0], vp, StoryUi.logical(self).y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	_focus_best_level.call_deferred()


func _focus_best_level() -> void:
	var pick: ChamferButton = null
	for i in level_nodes.size():
		if level_nodes[i].focus_mode == Control.FOCUS_NONE:
			continue
		pick = level_nodes[i]
		if StoryProgress.stars(_levels_of(open_stage)[i].id) == 0:
			break
	if pick != null and pick.is_inside_tree():
		pick.grab_focus()


func _levels_of(stage: String) -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for level in _levels:
		if level.stage == stage:
			out.append(level)
	return out


func _build_stage_strip(small: bool) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 5 if small else 6)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for stage in StoryUi.STAGES:
		var playable: bool = not _levels_of(stage).is_empty()
		var chip: ChamferButton = ChamferButton.make_card()
		chip.padding = Vector4(6, 5, 6, 5)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.focus_mode = Control.FOCUS_NONE
		chip.selected = stage == open_stage
		chip.modulate.a = 1.0 if playable else 0.55
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var stage_open: bool = playable and StoryProgress.is_unlocked(_levels_of(stage)[0])
		var name_label: Label = UiUtil.label(tr("STORY_STAGE_%s_NICK" % stage), "TitleLabel", 12 if small else 13, Palette.BRASS_BRIGHT if stage_open else Palette.IVORY)
		name_label.clip_text = true
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		var state: String = tr("STORY_STATE_OPEN") if stage_open else (tr("STORY_STATE_LOCKED") if playable else tr("STORY_STATE_SOON"))
		var state_label: Label = UiUtil.label(state, "HintLabel", 9, Palette.BRASS if stage_open else Palette.IVORY_MUTED)
		state_label.clip_text = true
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(state_label)
		chip.add_child(col)
		if playable:
			chip.pressed.connect(_on_stage_pressed.bind(stage))
		strip.add_child(chip)
		stage_chips.append(chip)
	return strip


func _on_stage_pressed(stage: String) -> void:
	if stage != open_stage:
		open_stage = stage
		_build()


func _build_stage_detail(small: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8 if small else 12)
	var line: String = "%s · %s — %s" % [tr("STORY_STAGE_%s_NICK" % open_stage), tr("STORY_STAGE_%s" % open_stage), tr("STORY_STAGE_%s_BLURB" % open_stage)]
	var blurb := HBoxContainer.new()
	blurb.add_theme_constant_override("separation", 10)
	var text: Label = StoryUi.paragraph(line, 12 if small else 13, Palette.IVORY_HINT)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	blurb.add_child(text)
	help_button = StoryUi.icon_button("?")
	help_button.name = "StageHelpButton"
	help_button.tooltip_text = tr("STAGECARD_HELP_TOOLTIP")
	help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help_button.custom_minimum_size.x = StoryUi.tap_height(self) * 1.1
	help_button.pressed.connect(open_stage_card)
	blurb.add_child(help_button)
	box.add_child(blurb)
	var path := HBoxContainer.new()
	path.add_theme_constant_override("separation", 6)
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level in _levels_of(open_stage):
		var node: ChamferButton = _make_level_node(level, small)
		path.add_child(node)
		level_nodes.append(node)
	box.add_child(path)
	return box


## True for the last node of a stage: the boss level (its id ends in `_boss`).
static func is_boss_level(level: LevelDef) -> bool:
	return level.id.ends_with("_boss")


## Red-tinted frame for the boss node.
func _style_boss(node: ChamferButton) -> void:
	var red: Color = Palette.TEAM_CRIMSON
	node.look_normal = {"top": Color(red, 0.14), "bottom": Color(red, 0.05), "border": Color(red, 0.7)}
	node.look_hover = {"top": Color(red, 0.24), "bottom": Color(red, 0.1), "border": Palette.BRASS_BRIGHT}
	node.look_selected = {"top": Color(red, 0.34), "bottom": Color(red, 0.1), "border": Palette.BRASS_BRIGHT}
	node.border_width = 2.0


func _make_level_node(level: LevelDef, small: bool) -> ChamferButton:
	var unlocked: bool = StoryProgress.is_unlocked(level)
	var node: ChamferButton = ChamferButton.make_card()
	node.name = "Level_%s" % level.id
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.padding = Vector4(8, 8, 8, 8)
	node.selected = unlocked and StoryProgress.stars(level.id) == 0
	var is_boss: bool = is_boss_level(level)
	if is_boss:
		_style_boss(node)
	node.modulate.a = 1.0 if unlocked else 0.5
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	var level_label: Label = UiUtil.spaced_label(UiUtil.fmt("STORY_LEVEL_N", [level.order]), "SectionLabel", 12 if small else 11, Palette.TEAM_CRIMSON if is_boss else Palette.BRASS, 1.2)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	if is_boss:
		head.add_child(BossCrown.new())
	col.add_child(head)
	var title: Label = UiUtil.label(tr(level.title_key) if level.playable else tr("STORY_STATE_SOON"), "BodyBoldLabel", 13 if small else 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	if unlocked:
		var stars := StarRow.new()
		stars.star_size = 14.0 if small else 16.0
		stars.count = StoryProgress.stars(level.id)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(stars)
	else:
		var state: String = tr("STORY_STATE_SOON") if not level.playable else tr("STORY_STATE_LOCKED")
		col.add_child(UiUtil.label(state, "HintLabel", 12 if small else 10, Palette.IVORY_MUTED))
	node.add_child(col)
	if unlocked:
		node.pressed.connect(open_level.bind(level))
	else:
		node.focus_mode = Control.FOCUS_NONE
		node.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return node
