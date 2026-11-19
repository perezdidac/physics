## Stage card: how a life stage plays (kind of game, goal, the on-screen controls, a few tips). Shown the first time the player opens a level of
## a stage, before the level card, and again from the "?" button of the story map.
## Keyboard: Enter/Space "Got it!", Esc back to the map.
class_name StageCard
extends Control

## Stage to explain when the card is opened without a story level (the "?" of the map sets it).
static var stage_id: String = ""
## True when opened from the map's "?": "Got it!" then closes to the map instead of going on to the level card.
static var from_map: bool = false

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var stage: String = ""
var back_button: Button
var ok_button: ChamferButton

const CARD_PX := 14
const SECTION_PX := 13
const CHIP := 50.0
## The texts are built at `_fit` times their size: 1.0, then smaller steps (down to MIN_FIT) while the card does not fit without scrolling.
const MIN_FIT := 0.7
const FIT_STEP := 0.06
var _fit: float = 1.0
var _scroll: ScrollContainer

## Number of tips every stage has.
const TIPS := 3


## Opens the card of `stage_name` from the story map.
static func request(stage_name: String, opened_from_map: bool) -> void:
	stage_id = stage_name
	from_map = opened_from_map


## Keys of the texts of one stage (all of them must exist in both languages).
static func text_keys(stage_name: String) -> Array[String]:
	var keys: Array[String] = ["STORY_STAGE_%s" % stage_name, "STORY_STAGE_%s_NICK" % stage_name]
	for part: String in ["KIND", "GOAL", "KEYS"]:
		keys.append("STAGECARD_%s_%s" % [stage_name, part])
	for i in TIPS:
		keys.append("STAGECARD_%s_TIP%d" % [stage_name, i + 1])
	return keys


## The controls of a stage: entries `{"chips": [[Kind, label key or ""], ...], "cap": caption key}`. The labels reuse the keys of the real
## buttons (PLAT_JUMP, HUD_FLIP...), so the card always says what the buttons say.
static func controls(stage_name: String) -> Array[Dictionary]:
	var left: Array = [StageChip.Kind.LEFT, ""]
	var right: Array = [StageChip.Kind.RIGHT, ""]
	var walk: Dictionary = {"chips": [left, right], "cap": "STAGECARD_CAP_MOVE"}
	var aim: Dictionary = {"chips": [[StageChip.Kind.ROUND, "TOUCH_AIM_BUTTON"]], "cap": "STAGECARD_CAP_AIM"}
	var fire: Dictionary = {"chips": [[StageChip.Kind.FIRE, "FIRE_DEFAULT"]], "cap": "STAGECARD_CAP_FIRE"}
	var pass_turn: Dictionary = {"chips": [[StageChip.Kind.PILL, "HUD_PASS"]], "cap": "STAGECARD_CAP_PASS"}
	var switch: Dictionary = {"chips": [[StageChip.Kind.PILL, "HUD_SWITCH_WORM"]], "cap": "STAGECARD_CAP_SWITCH"}
	var jump: Dictionary = {"chips": [[StageChip.Kind.ROUND, "HUD_JUMP"]], "cap": "STAGECARD_CAP_JUMP_FWD"}
	var flip: Dictionary = {"chips": [[StageChip.Kind.ROUND, "HUD_FLIP"]], "cap": "STAGECARD_CAP_FLIP"}
	var out: Array[Dictionary] = []
	match stage_name:
		"EGG":
			out.assign([{"chips": [left, right], "cap": "STAGECARD_CAP_RUN"}, {"chips": [[StageChip.Kind.ROUND, "PLAT_JUMP"]], "cap": "STAGECARD_CAP_JUMP"}])
		"LARVA_EARLY", "LARVA":
			out.assign([walk, jump, flip, aim, fire, pass_turn, switch])
		"NEST":
			out.assign([walk, jump, aim, fire, {"chips": [[StageChip.Kind.PILL, "HUD_REPAIR"]], "cap": "STAGECARD_CAP_REPAIR"}, pass_turn, switch])
		"PROCESSION":
			out.assign([{"chips": [left, right], "cap": "STAGECARD_CAP_MARCH"}, jump, aim, fire, pass_turn])
		"PUPA":
			out.assign([{"chips": [left, [StageChip.Kind.UP, ""], [StageChip.Kind.DOWN, ""], right], "cap": "STAGECARD_CAP_DIG"}, {"chips": [[StageChip.Kind.ROUND, "PLAT_JUMP"]], "cap": "STAGECARD_CAP_HOP"}])
		"MOTH":
			out.assign([{"chips": [left, right], "cap": "STAGECARD_CAP_STEER"}, {"chips": [[StageChip.Kind.WINGS, "PLAT_FLAP"]], "cap": "STAGECARD_CAP_FLAP"}])
	return out


func _ready() -> void:
	theme = UiUtil.get_theme()
	stage = stage_id
	if GameState.story_level != null and not from_map:
		stage = GameState.story_level.stage
	if stage.is_empty() or not StoryUi.STAGES.has(stage):
		_go.call_deferred("story_map")
		return
	StoryProgress.mark_stage_intro_seen(stage)
	_build()
	get_viewport().size_changed.connect(_on_resized)


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


## "Got it!": on to the level card (first time) or back to the map (opened with "?").
func accept() -> void:
	UiUtil.sfx("tick")
	_go("story_map" if from_map or GameState.story_level == null else "level_intro")


## Leaves to the campaign map.
func back_to_map() -> void:
	UiUtil.sfx("tick")
	_go("story_map")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_to_map()


func _on_resized() -> void:
	_fit = 1.0
	_build()


## A font size scaled by `_fit`.
func _px(base: int) -> int:
	return maxi(9, int(round(base * _fit)))


## Shrinks the texts one step and rebuilds while the content is taller than its scroll area.
func _shrink_to_fit() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or _scroll == null or not is_instance_valid(_scroll) or _scroll.get_child_count() == 0:
		return
	var content: Control = _scroll.get_child(0) as Control
	if content.get_combined_minimum_size().y > _scroll.size.y + 1.0 and _fit > MIN_FIT:
		_fit = maxf(MIN_FIT, _fit - FIT_STEP)
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	var lvp: Vector2 = StoryUi.logical(self)
	var small: bool = StoryUi.is_small(vp)
	var map_idx: int = GameState.story_level.map_idx if GameState.story_level != null else 0
	var parts: Array = StoryUi.make_frame(self, map_idx)
	var body: VBoxContainer = parts[1]
	_scroll = body.get_parent() as ScrollContainer
	var footer: HBoxContainer = parts[2]
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14 if lvp.x < StoryUi.NARROW_WIDTH else 22)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)

	var kicker: String = "%s · %s · %s" % [tr("STORY_STAGE_%s_NICK" % stage), tr("STORY_STAGE_%s" % stage), tr("STAGECARD_KICKER")]
	left.add_child(UiUtil.spaced_label(kicker.to_upper(), "MonoLabel", _px(13), Palette.KICKER_ORANGE, 1.4))
	var h1: Label = UiUtil.spaced_label(tr("STAGECARD_%s_KIND" % stage).to_upper(), "TitleBlackLabel", _px(24 if small else 28), Palette.BRASS_BRIGHT, 2.0)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(h1)
	var goal_box := ChamferPanel.new()
	goal_box.cuts = Vector4(0, 8, 0, 8)
	goal_box.padding = Vector4(12, 8, 12, 8)
	goal_box.fill_top = Color(Palette.BRASS, 0.20)
	goal_box.fill_bottom = Color(Palette.BRASS, 0.08)
	goal_box.border_color = Palette.BRASS_BRIGHT
	goal_box.border_width = 1.5
	var goal_col := VBoxContainer.new()
	goal_col.add_theme_constant_override("separation", 3)
	goal_box.add_child(goal_col)
	goal_col.add_child(StoryUi.section(tr("STAGECARD_LABEL_GOAL"), _px(SECTION_PX)))
	goal_col.add_child(StoryUi.paragraph(tr("STAGECARD_%s_GOAL" % stage), _px(16 if small else 17), Palette.BRASS_BRIGHT))
	left.add_child(goal_box)
	var tips: VBoxContainer = _info_card(left, tr("STAGECARD_LABEL_TIPS"))
	for i in TIPS:
		tips.add_child(StoryUi.paragraph("• " + tr("STAGECARD_%s_TIP%d" % [stage, i + 1]), _px(CARD_PX + 1), Palette.IVORY_MUTED))

	var ctl: VBoxContainer = _info_card(right, tr("STAGECARD_LABEL_CONTROLS"))
	ctl.add_child(_build_controls())
	var keys: VBoxContainer = _info_card(right, tr("STAGECARD_LABEL_KEYS"))
	keys.add_child(StoryUi.paragraph(tr("STAGECARD_%s_KEYS" % stage), _px(CARD_PX), Palette.IVORY_MUTED))

	back_button = null
	if not from_map:
		back_button = StoryUi.cmd_button(tr("STORY_BTN_BACK"))
		back_button.pressed.connect(back_to_map)
		footer.add_child(back_button)
	ok_button = StoryUi.deploy_button(tr("STAGECARD_BTN_OK"))
	ok_button.pressed.connect(accept)
	footer.add_child(ok_button)
	TouchMetrics.fit_taps(parts[0], vp, lvp.y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	ok_button.grab_focus.call_deferred()
	_shrink_to_fit()


## The picture of every control with its caption under it, wrapping onto more rows when the column is narrow.
func _build_controls() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 8)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d: float = CHIP * clampf(_fit, 0.8, 1.0)
	for entry in controls(stage):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var width: float = 0.0
		for chip: Array in entry["chips"]:
			var label: String = tr(chip[1]) if chip[1] != "" else ""
			if chip[0] == StageChip.Kind.PILL:
				label = label.to_upper()
			var c: StageChip = StageChip.make(chip[0], label, d)
			row.add_child(c)
			width += c.custom_minimum_size.x + 5.0
		col.add_child(row)
		var cap: Label = UiUtil.label(tr(entry["cap"]), "HintLabel", _px(11), Palette.IVORY_HINT)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.custom_minimum_size.x = maxf(width - 5.0, 100.0 * clampf(_fit, 0.8, 1.0))
		col.add_child(cap)
		flow.add_child(col)
	return flow


## A compact card (heading plus the lines the caller adds) at the end of `column`; returns its inner box.
func _info_card(column: VBoxContainer, heading: String) -> VBoxContainer:
	var card := ChamferPanel.new()
	card.cuts = Vector4(0, 7, 0, 0)
	card.padding = Vector4(10, 6, 10, 6)
	card.fill_top = Color(1, 1, 1, 0.04)
	card.fill_bottom = Color(1, 1, 1, 0.02)
	card.border_color = Palette.IVORY_FAINT
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(StoryUi.section(heading, _px(SECTION_PX)))
	card.add_child(col)
	column.add_child(card)
	return col
