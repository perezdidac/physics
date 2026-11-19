## Level card: stage nickname and hero name, what the real stage is like, the goal, the tip, the enemies and the weapons.
## Keyboard: Enter/Space play (the Play button has focus), Esc back to the map.
extends Control

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var level: LevelDef
var back_button: Button
var play_button: ChamferButton

## Text sizes (logical px, before the UI scale) of the side cards and their headings, at full size.
const CARD_PX := 14
const SECTION_PX := 13
## The texts are built at `_fit` times their size: 1.0, then smaller steps (down to MIN_FIT) while a long level does not fit without scrolling.
const MIN_FIT := 0.7
const FIT_STEP := 0.06
var _fit: float = 1.0
var _scroll: ScrollContainer


func _ready() -> void:
	theme = UiUtil.get_theme()
	level = GameState.story_level
	if level == null:
		_go.call_deferred("story_map")
		return
	_build()
	get_viewport().size_changed.connect(_on_resized)


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


## Leaves to the campaign map.
func back_to_map() -> void:
	UiUtil.sfx("tick")
	_go("story_map")


## Starts the level.
func play() -> void:
	UiUtil.sfx("title_fanfare")
	GameState.story_level = level
	GameState.has_started_match = true
	_go("platform" if level.mode == "PLATFORM" else "combat")


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
	var parts: Array = StoryUi.make_frame(self, level.map_idx)
	var body: VBoxContainer = parts[1]
	_scroll = body.get_parent() as ScrollContainer
	var footer: HBoxContainer = parts[2]
	var stage: String = level.stage
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if lvp.x < StoryUi.NARROW_WIDTH:
		columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)

	var kicker: String = "%s · %s · %s" % [tr("STORY_STAGE_%s_NICK" % stage), tr("STORY_STAGE_%s" % stage), UiUtil.fmt("STORY_LEVEL_N", [level.order])]
	left.add_child(UiUtil.spaced_label(kicker.to_upper(), "MonoLabel", _px(13), Palette.KICKER_ORANGE, 1.4))
	var h1: Label = UiUtil.spaced_label(tr(level.title_key).to_upper(), "TitleBlackLabel", _px(26 if small else 30), Palette.BRASS_BRIGHT, 2.0)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(h1)
	left.add_child(StoryUi.paragraph(tr("STORY_HERO_%s" % stage), _px(14 if small else 15), Palette.IVORY_MUTED))
	left.add_child(StoryUi.paragraph(tr(level.intro_key), _px(16 if small else 17)))
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
	goal_col.add_child(StoryUi.section(tr("STORY_LABEL_GOAL"), _px(SECTION_PX)))
	goal_col.add_child(StoryUi.paragraph(StoryUi.level_text(level.goal_key, level), _px(16 if small else 17), Palette.BRASS_BRIGHT))
	left.add_child(goal_box)

	var real: VBoxContainer = _info_card(right, tr("STORY_LABEL_REAL"))
	real.add_child(StoryUi.paragraph(tr("STORY_STAGE_%s_FACT" % stage), _px(CARD_PX), Palette.IVORY_MUTED))
	var tip: VBoxContainer = _info_card(right, tr("STORY_LABEL_TIP"))
	tip.add_child(StoryUi.paragraph(tr(level.tip_key), _px(CARD_PX), Palette.IVORY_MUTED))
	if level.boss != null:
		_add_boss_card(real, tip)
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 1)
	left.add_child(facts) # under the goal: the left column has the room, the cards fill the right one
	var rules: Array[String] = rule_lines()
	for line in rules:
		facts.add_child(StoryUi.paragraph(line, _px(CARD_PX), Palette.IVORY_MUTED))
	if level.boss == null:
		facts.add_child(_fact_line(tr("STORY_LABEL_ENEMIES"), enemies_text()))
	facts.add_child(_fact_line(tr("STORY_LABEL_WEAPONS"), weapons_text()))
	if not level.abilities.is_empty():
		facts.add_child(_fact_line(tr("STORY_LABEL_ABILITIES"), abilities_text()))

	back_button = StoryUi.cmd_button(tr("STORY_BTN_BACK"))
	back_button.pressed.connect(back_to_map)
	footer.add_child(back_button)
	play_button = StoryUi.deploy_button(tr("STORY_BTN_PLAY"))
	play_button.pressed.connect(play)
	footer.add_child(play_button)
	TouchMetrics.fit_taps(parts[0], vp, lvp.y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	play_button.grab_focus.call_deferred()
	_shrink_to_fit()


## Boss levels: the boss name and title and how it attacks go in the tip card, a line of real biology in the "real life" card
## (texts keyed by the BossDef name key without "_NAME").
func _add_boss_card(real: VBoxContainer, tip: VBoxContainer) -> void:
	var def: BossDef = level.boss
	var prefix: String = def.name_key.trim_suffix("_NAME")
	var fact: String = tr(prefix + "_FACT")
	if fact != prefix + "_FACT":
		real.add_child(StoryUi.paragraph(fact, _px(CARD_PX), Palette.IVORY_MUTED))
	tip.add_child(StoryUi.paragraph("%s · %s" % [tr(def.name_key), tr(def.title_key)], _px(CARD_PX), Palette.TEAM_CRIMSON))
	var attacks: String = tr(prefix + "_ATTACKS")
	if attacks != prefix + "_ATTACKS":
		tip.add_child(StoryUi.paragraph(attacks, _px(CARD_PX), Palette.IVORY_MUTED))
	var allies: String = enemies_text()
	if allies != tr("STORY_NONE"):
		tip.add_child(StoryUi.paragraph(allies, _px(CARD_PX), Palette.IVORY_MUTED))


## A compact card (heading plus the lines the caller adds) at the end of `column`; returns its inner box.
func _info_card(column: VBoxContainer, heading: String) -> VBoxContainer:
	var card := ChamferPanel.new()
	card.cuts = Vector4(0, 7, 0, 0)
	card.padding = Vector4(10, 6, 10, 6)
	card.fill_top = Color(1, 1, 1, 0.04)
	card.fill_bottom = Color(1, 1, 1, 0.02)
	card.border_color = Palette.IVORY_FAINT
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(StoryUi.section(heading, _px(SECTION_PX)))
	card.add_child(col)
	column.add_child(card)
	return col


## "Heading: text" in one small wrapping line.
func _fact_line(heading: String, text: String) -> Label:
	return StoryUi.paragraph("%s: %s" % [heading, text], _px(CARD_PX), Palette.IVORY_MUTED)


## Special rules of the level, one line each: defend the nest (with the repair key), the cold, the forestry pole, and how the digging and
## flying levels are played.
func rule_lines() -> Array[String]:
	var lines: Array[String] = []
	if level.win_rule == "DEFEND_NEST":
		lines.append(UiUtil.fmt("STORY_RULE_DEFEND", [level.survive_rounds, level.nest_hp]))
	elif level.nest_hp > 0:
		lines.append(UiUtil.fmt("STORY_RULE_NEST_BOSS", [level.nest_hp]))
	if level.nest_hp > 0:
		lines.append(tr("STORY_RULE_REPAIR"))
	if level.cold:
		lines.append(tr("STORY_RULE_COLD"))
	if level.pole:
		lines.append(tr("STORY_RULE_POLE"))
	if level.mode == "PLATFORM" and level.layout != null and level.layout.mode != "":
		lines.append(tr("STORY_MODE_" + level.layout.mode))
	if level.is_convoy():
		lines.append_array(convoy_lines())
	if level.mode == "COMBAT":
		lines.append_array(goal_lines())
	return lines


## Rules of the levels of the second pass: the goal of REACH, RESCUE, COLLECT and ONE_SHOT, the anthill's HP, the barrels and mines, and the
## twist of the level (strong wind, tide, supply crates, hiding spots).
func goal_lines() -> Array[String]:
	var lines: Array[String] = []
	match level.win_rule:
		"REACH":
			lines.append(UiUtil.fmt("STORY_RULE_REACH", [level.survive_rounds]))
		"RESCUE":
			lines.append(UiUtil.fmt("STORY_RULE_RESCUE", [level.survive_rounds]))
		"COLLECT":
			lines.append(UiUtil.fmt("STORY_RULE_COLLECT", [level.collect_count, level.collect_need, level.survive_rounds]))
		"ONE_SHOT":
			lines.append(tr("STORY_RULE_ONE_SHOT"))
	if level.win_rule == "WAVES" and level.anthill_hp > 0:
		lines.append(UiUtil.fmt("STORY_RULE_ANTHILL", [level.anthill_hp]))
	if level.barrels > 0:
		lines.append(UiUtil.fmt("STORY_RULE_BARRELS_ANTHILL" if level.win_rule == "WAVES" else "STORY_RULE_BARRELS", [level.barrels]))
	if level.mines > 0:
		lines.append(UiUtil.fmt("STORY_RULE_MINES", [level.mines]))
	if level.wind_scale >= 1.25:
		lines.append(UiUtil.fmt("STORY_RULE_WIND", [roundi((level.wind_scale - 1.0) * 100.0)]))
	if level.tide:
		lines.append(UiUtil.fmt("STORY_RULE_TIDE", [level.tide_round]))
	if level.supply_drops:
		lines.append(tr("STORY_RULE_SUPPLY"))
	if level.hiding_spots > 0:
		lines.append(tr("STORY_RULE_HIDE"))
	return lines


## La Processó levels: how the file works (leader, march budget, lost followers) and the hazards of this level (boar, fungus, the big enemy).
func convoy_lines() -> Array[String]:
	var lines: Array[String] = [tr("STORY_RULE_CONVOY"), UiUtil.fmt("STORY_RULE_MARCH", [int(level.march_budget)]), tr("STORY_RULE_LOST")]
	if not level.boar_rounds.is_empty():
		lines.append(tr("STORY_RULE_BOAR"))
	if not level.spores.is_empty():
		lines.append(tr("STORY_RULE_SPORES"))
	if level.mini_boss != "" or level.win_rule == "BOSS_OR_GOAL":
		lines.append(tr("STORY_RULE_MINI_BOSS"))
	return lines


## What hurts in a platform level: its boss, or its ants, falling stones, flood, traps, lamps and nightjars.
func platform_enemies_text() -> String:
	var layout: PlatformLayout = level.layout
	if layout.boss != "":
		return tr("PLAT_ENEMY_WASP") if layout.boss == "WASP" else tr("STORY_ENEMY_" + layout.boss)
	var parts: Array[String] = []
	if not layout.ants.is_empty():
		var ant_name: String = tr(level.enemy_unit.name_key) if level.enemy_unit != null else tr("UNIT_ANT")
		parts.append("%s × %d" % [ant_name, layout.ants.size()])
	if not layout.stones.is_empty():
		parts.append(UiUtil.fmt("STORY_ENEMY_STONES", [layout.stones.size()]))
	if layout.flood_rate > 0.0:
		parts.append(tr("STORY_ENEMY_WATER"))
	if not layout.lights.is_empty():
		parts.append(UiUtil.fmt("STORY_ENEMY_LAMPS", [layout.lights.size()]))
	if not layout.traps.is_empty():
		parts.append(UiUtil.fmt("STORY_ENEMY_TRAPS", [layout.traps.size()]))
	if not layout.nightjars.is_empty():
		parts.append(UiUtil.fmt("STORY_ENEMY_NIGHTJARS", [layout.nightjars.size()]))
	return ", ".join(parts) if not parts.is_empty() else tr("STORY_NONE")


## "Ant × 2, Blue tit × 1" for the enemy squad (mixed teams list every kind; an anthill says how many come each wave).
func enemies_text() -> String:
	if level.mode == "PLATFORM" and level.layout != null:
		return platform_enemies_text()
	if level.win_rule == "WAVES" and level.enemy_unit != null:
		return UiUtil.fmt("STORY_ENEMIES_WAVE", [tr(level.enemy_unit.name_key), level.wave_size])
	var counts: Dictionary = {}
	for unit in level.enemy_roster():
		counts[unit] = int(counts.get(unit, 0)) + 1
	if counts.is_empty():
		return tr("STORY_NONE")
	var parts: Array[String] = []
	for unit: UnitDef in counts:
		parts.append("%s × %d" % [tr(unit.name_key), counts[unit]])
	return ", ".join(parts)


## Ids of the weapons of the level: its own arsenal plus the ones unlocked by the levels already won.
func weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in level.player_arsenal:
		ids.append(id)
	if level.use_unlocked:
		for id in StoryProgress.unlocked_weapons():
			if not ids.has(id):
				ids.append(id)
	return ids


## Names of the weapons the player has, or the "none: hide!" line.
func weapons_text() -> String:
	if level.mode == "PLATFORM":
		return tr("PLAT_NO_WEAPONS")
	var ids: Array[String] = weapon_ids()
	if ids.is_empty():
		return tr("STORY_NO_WEAPONS")
	var names: Array[String] = []
	for id in ids:
		var amount: int = int(level.player_arsenal.get(id, -1))
		names.append("%s ×%d" % [StoryUi.weapon_name(id), amount] if level.win_rule == "ONE_SHOT" and amount > 0 else StoryUi.weapon_name(id))
	return ", ".join(names)


## Names of the special abilities of the level (the silk thread).
func abilities_text() -> String:
	var names: Array[String] = []
	for ability in level.abilities:
		names.append(tr("STORY_ABILITY_" + ability))
	return ", ".join(names)
