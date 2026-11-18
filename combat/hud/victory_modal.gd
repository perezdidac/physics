## Victory modal shown when the match ends: winner title, map/rounds/damage/MVP stats, and the two buttons
## (change map/squad -> lobby, play again -> new combat with the same settings).
## Keys: Left/Right/A/D/Tab swap the focused button, Enter/Space activate, Esc exits to the boot menu.
## `bind(sim)` connects the sim's `game_over(winner, stats)`. `stats` keys are all optional and fall back to sim fields:
## `round_number`, `team_damage_dealt` ([d0, d1]), `mvp_name`, `mvp_damage`.
class_name VictoryModal
extends Control

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var sim: Variant = null
var focus_idx: int = 1
var title_label: Label
var sub_label: Label
var stats_grid: GridContainer
var mvp_box: VBoxContainer
var lobby_button: Button
var rematch_button: ChamferButton
var is_open: bool = false


func _ready() -> void:
	theme = UiUtil.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## Connects the sim signal `game_over`.
func bind(new_sim: Variant) -> void:
	sim = new_sim
	if sim != null and sim.has_signal("game_over"):
		sim.game_over.connect(show_result)


## Fills the card for `winner` (0, 1, or -1 for a draw) and shows the modal.
func show_result(winner: int, stats: Variant = null) -> void:
	var map_name: String = tr(UiMaps.name_key(clampi(GameState.map_idx, 0, UiMaps.IDS.size() - 1)))
	match winner:
		0:
			title_label.text = tr("VICTORY_TITLE_0")
			title_label.add_theme_color_override("font_color", Palette.TEAM_GOLD)
			sub_label.text = UiUtil.fmt("VICTORY_SUB_0", [map_name])
		1:
			title_label.text = tr("VICTORY_TITLE_1")
			title_label.add_theme_color_override("font_color", Palette.TEAM_CRIMSON)
			sub_label.text = UiUtil.fmt("VICTORY_SUB_1", [map_name])
		_:
			title_label.text = tr("VICTORY_TITLE_DRAW")
			title_label.add_theme_color_override("font_color", Palette.IVORY)
			sub_label.text = tr("VICTORY_SUB_DRAW")
	var rounds: int = int(_stat(stats, "round_number", UiUtil.prop(sim, "round_number", 1)))
	var dmg: Variant = _stat(stats, "team_damage_dealt", UiUtil.prop(sim, "team_damage_dealt", [0, 0]))
	var d0: int = int(dmg[0]) if dmg is Array and (dmg as Array).size() > 0 else 0
	var d1: int = int(dmg[1]) if dmg is Array and (dmg as Array).size() > 1 else 0
	var mvp: Array = _find_mvp(stats)
	for c in stats_grid.get_children():
		stats_grid.remove_child(c)
		c.queue_free()
	_add_stat(tr("VICTORY_STAT_MAP"), map_name, Palette.IVORY)
	_add_stat(tr("VICTORY_STAT_ROUNDS"), str(rounds), Palette.IVORY)
	_add_stat(tr("VICTORY_STAT_DMG_0"), UiUtil.fmt("HUD_HP_TOTAL", [d0]), Palette.TEAM_GOLD)
	_add_stat(tr("VICTORY_STAT_DMG_1"), UiUtil.fmt("HUD_HP_TOTAL", [d1]), Palette.TEAM_CRIMSON)
	var mvp_row := HBoxContainer.new()
	mvp_row.add_theme_constant_override("separation", 6)
	mvp_row.add_child(UiUtil.label(tr("VICTORY_STAT_MVP"), "BodyBoldLabel", 13, Palette.BRASS_BRIGHT))
	mvp_row.add_child(UiUtil.label(UiUtil.fmt("VICTORY_MVP_VALUE", [mvp[0], mvp[1]]), "MutedLabel", 13, Palette.IVORY))
	for c in mvp_box.get_children():
		mvp_box.remove_child(c)
		c.queue_free()
	mvp_box.add_child(HSeparator.new())
	mvp_box.add_child(mvp_row)
	is_open = true
	visible = true
	focus_idx = 1
	_apply_focus()


func _stat(stats: Variant, key: String, fallback: Variant) -> Variant:
	if stats is Dictionary and (stats as Dictionary).has(key):
		return (stats as Dictionary)[key]
	return fallback


## Returns [name, damage] of the caterpillar that dealt most damage (first wins ties; "—" and 0 if none).
func _find_mvp(stats: Variant) -> Array:
	if stats is Dictionary and (stats as Dictionary).has("mvp_name"):
		return [str(stats["mvp_name"]), int((stats as Dictionary).get("mvp_damage", 0))]
	var best: Variant = null
	var best_dmg: float = -1.0
	for f: Variant in UiUtil.prop(sim, "fighters", []):
		var d: float = float(UiUtil.prop(f, "dmg_dealt", 0.0))
		if d > best_dmg:
			best = f
			best_dmg = d
	if best == null:
		return ["—", 0]
	return [str(UiUtil.prop(best, "name", "—")), int(best_dmg)]


func _add_stat(label_text: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UiUtil.label(label_text, "MutedLabel", 13))
	row.add_child(UiUtil.label(value, "BodyBoldLabel", 13, value_color))
	stats_grid.add_child(row)


## Hides the modal.
func close() -> void:
	is_open = false
	visible = false


## Runs the lobby button (change map/squad).
func go_lobby() -> void:
	_go("lobby")


## Runs the rematch button: a new combat with the same settings.
func rematch() -> void:
	_go("combat")


func _go(screen_name: String) -> void:
	close()
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


func _apply_focus() -> void:
	(lobby_button if focus_idx == 0 else rematch_button).grab_focus()


func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	handle_key(key.keycode)
	get_viewport().set_input_as_handled()


## Applies one key press while open (everything else is swallowed, as in the original). Exposed for tests.
func handle_key(keycode: Key) -> void:
	match keycode:
		KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_TAB:
			focus_idx = 1 - focus_idx
			UiUtil.sfx("tick")
			_apply_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			UiUtil.sfx("tick")
			if focus_idx == 0:
				go_lobby()
			else:
				rematch()
		KEY_ESCAPE:
			_go("boot")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Palette.OVERLAY_DARK
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vp: Vector2 = get_viewport_rect().size
	var compact: bool = UiUtil.is_compact(vp)
	var card := ChamferPanel.new()
	card.cuts = Vector4(0, 16, 0, 16)
	card.border_color = Palette.BRASS_BRIGHT
	card.border_width = 1.5
	card.padding = Vector4(24, 14, 24, 14) if compact else Vector4(32, 28, 32, 28)
	card.custom_minimum_size.x = minf(540.0, vp.x * 0.92)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6 if compact else 12)
	card.add_child(col)
	var kicker: Label = UiUtil.spaced_label(tr("VICTORY_KICKER"), "TitleLabel", 12, Palette.KICKER_ORANGE, 3.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	title_label = UiUtil.label("", "TitleBlackLabel", 20 if compact else 28, Palette.TEAM_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title_label)
	sub_label = UiUtil.label("", "MutedLabel", 13)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub_label)
	var box := ChamferPanel.new()
	box.fill_top = Palette.MODAL_BOX_FILL
	box.fill_bottom = Palette.MODAL_BOX_FILL
	box.border_color = Palette.MODAL_BOX_BORDER
	box.padding = Vector4(14, 10, 14, 10)
	col.add_child(box)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 8)
	box.add_child(stats_box)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_box.add_child(stats_grid)
	mvp_box = VBoxContainer.new()
	mvp_box.add_theme_constant_override("separation", 6)
	stats_box.add_child(mvp_box)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	lobby_button = Button.new()
	lobby_button.theme_type_variation = "CmdButton"
	lobby_button.text = tr("VICTORY_BTN_LOBBY").to_upper()
	lobby_button.pressed.connect(go_lobby)
	buttons.add_child(lobby_button)
	rematch_button = ChamferButton.make_deploy()
	var rl: Label = UiUtil.spaced_label(tr("VICTORY_BTN_REMATCH"), "TitleBlackLabel", 13, Palette.INK_ON_BRASS, 1.4)
	rematch_button.add_child(rl)
	rematch_button.pressed.connect(rematch)
	buttons.add_child(rematch_button)
