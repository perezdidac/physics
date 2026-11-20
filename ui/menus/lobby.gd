## Custom match setup: mode, CPU difficulty, worms per team, map, squad names, hats and faces.
## Keyboard follows the original roving cursor (main.js:1119-1357): Up/Down jump between groups, Left/Right move inside a row and select
## cards, Tab/Shift+Tab cycle, Enter/Space activate, Ctrl+Enter deploys, Esc leaves.
extends Control

const MODE_CARDS: Array[Array] = [
	["1P_CPU", "LOBBY_MODE_1P_TITLE", "LOBBY_MODE_1P_SUB"],
	["2P_LOCAL", "LOBBY_MODE_2P_TITLE", "LOBBY_MODE_2P_SUB"],
	["CPU_CPU", "LOBBY_MODE_CPU_TITLE", "LOBBY_MODE_CPU_SUB"],
]
const DIFF_CARDS: Array[Array] = [
	["ROOKIE", "LOBBY_DIFF_ROOKIE_TITLE", "LOBBY_DIFF_ROOKIE_SUB"],
	["VETERAN", "LOBBY_DIFF_VETERAN_TITLE", "LOBBY_DIFF_VETERAN_SUB"],
	["NIGHTMARE", "LOBBY_DIFF_NIGHTMARE_TITLE", "LOBBY_DIFF_NIGHTMARE_SUB"],
]
const COUNT_KEYS: Array[Array] = [
	["LOBBY_COUNT_1_TITLE", "LOBBY_COUNT_1_SUB"],
	["LOBBY_COUNT_2_TITLE", "LOBBY_COUNT_2_SUB"],
	["LOBBY_COUNT_3_TITLE", "LOBBY_COUNT_3_SUB"],
	["LOBBY_COUNT_4_TITLE", "LOBBY_COUNT_4_SUB"],
	["LOBBY_COUNT_5_TITLE", "LOBBY_COUNT_5_SUB"],
	["LOBBY_COUNT_6_TITLE", "LOBBY_COUNT_6_SUB"],
]
const HAT_KEYS: Dictionary = {
	"VARIED": "HAT_VARIED",
	"CATALAN": "HAT_CATALAN",
	"CASTELLER": "HAT_CASTELLER",
	"BANDOLER": "HAT_BANDOLER",
	"PAGES": "HAT_PAGES",
	"BRISTLES": "HAT_BRISTLES",
}
## Option order of each team's hat select (differs between the two selects in the original HTML).
const HAT_ORDER: Array[Array] = [
	["VARIED", "CATALAN", "CASTELLER", "BANDOLER", "PAGES", "BRISTLES"],
	["VARIED", "BANDOLER", "CATALAN", "CASTELLER", "PAGES", "BRISTLES"],
]
const NARROW_WIDTH := 820.0

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var focus_idx: int = 0
var mode_cards: Array[ChamferButton] = []
var diff_cards: Array[ChamferButton] = []
var count_cards: Array[ChamferButton] = []
var map_cards: Array[ChamferButton] = []
var hat_selects: Array[OptionButton] = []
var name_inputs: Array = [[], []]
var random_button: Button
var deploy_button: ChamferButton
var back_button: Button
var close_button: Button
var _backdrop: MenuBackdrop
var _scroll: ScrollContainer
var _squad_columns: Array[VBoxContainer] = []
var _narrow: bool = false
var _compact: bool = false
var _face_dialog: FileDialog
var _face_target: Vector2i = Vector2i.ZERO
var _face_buttons: Dictionary = {}
var _theatre_images: Array[TextureRect] = []


func _ready() -> void:
	theme = UiUtil.get_theme()
	_build()
	get_viewport().size_changed.connect(_on_resized)


func _on_resized() -> void:
	var vp: Vector2 = TouchMetrics.logical_size(get_viewport_rect().size)
	if (vp.x < NARROW_WIDTH) != _narrow or UiUtil.is_compact(vp) != _compact:
		read_customization()
		_build()


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


# ---- state <-> UI ---------------------------------------------------------------------------

## Copies names and hats from the inputs into GameState (JS readLobbyCustomization).
func read_customization() -> void:
	for t in 2:
		for i in name_inputs[t].size():
			var le: LineEdit = name_inputs[t][i]
			if is_instance_valid(le):
				var txt: String = le.text.strip_edges()
				if not txt.is_empty():
					GameState.team_names[t][i] = txt
		if t < hat_selects.size() and is_instance_valid(hat_selects[t]):
			GameState.team_hats[t] = _hat_of(hat_selects[t])


func _hat_of(opt: OptionButton) -> String:
	return str(opt.get_item_metadata(opt.selected))


func _select_hat(opt: OptionButton, hat: String) -> void:
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == hat:
			opt.select(i)
			return


## Cycles a hat select +1/-1 over GameState.HAT_OPTIONS (not over the option order), like the original.
func cycle_hat(opt: OptionButton, step: int) -> void:
	var order: Array[String] = GameState.HAT_OPTIONS
	var cur: int = maxi(0, order.find(_hat_of(opt)))
	_select_hat(opt, order[posmod(cur + step, order.size())])
	read_customization()


func set_mode(mode: String) -> void:
	GameState.game_mode = mode
	_refresh_cards()


func set_difficulty(diff: String) -> void:
	GameState.ai_difficulty = diff
	_refresh_cards()


func set_count(count: int) -> void:
	read_customization()
	GameState.worms_per_team = clampi(count, 1, GameState.MAX_WORMS)
	_render_squad_rows()
	_refresh_cards()


func set_map(idx: int) -> void:
	GameState.map_idx = clampi(idx, 0, GameState.MAP_COUNT - 1)
	_backdrop.set_map(GameState.map_idx)
	_refresh_cards()


func _refresh_cards() -> void:
	for i in mode_cards.size():
		_mark(mode_cards[i], MODE_CARDS[i][0] == GameState.game_mode)
	for i in diff_cards.size():
		_mark(diff_cards[i], DIFF_CARDS[i][0] == GameState.ai_difficulty)
	for i in count_cards.size():
		_mark(count_cards[i], i + 1 == GameState.worms_per_team)
	for i in map_cards.size():
		var on: bool = i == GameState.map_idx
		map_cards[i].selected = on
		_theatre_images[i].modulate = Color(1, 1, 1, 1) if on else Color(0.84, 0.84, 0.84, 1)


func _mark(card: ChamferButton, on: bool) -> void:
	card.selected = on
	var title: Label = card.get_meta("title_label")
	title.add_theme_color_override("font_color", Palette.BRASS_BRIGHT if on else Palette.IVORY)


# ---- actions -------------------------------------------------------------------------------

## Leaves to the boot screen (header button and Esc).
func back_to_menu() -> void:
	read_customization()
	_go("boot")


## Starts the match with the current choices.
func deploy() -> void:
	read_customization()
	GameState.story_level = null
	GameState.has_custom_names = true
	GameState.has_started_match = true
	_go("combat")


func _on_random_names() -> void:
	GameState.randomize_names()
	GameState.has_custom_names = true
	_render_squad_rows()


# ---- keyboard ------------------------------------------------------------------------------

## Focusable controls in DOM order (same list as getLobbyFocusableItems).
func focus_items() -> Array[Control]:
	var out: Array[Control] = []
	out.append(back_button)
	for c in mode_cards:
		out.append(c)
	for c in diff_cards:
		out.append(c)
	for c in count_cards:
		out.append(c)
	for c in map_cards:
		out.append(c)
	out.append(hat_selects[0])
	for le: LineEdit in name_inputs[0]:
		out.append(le)
	out.append(hat_selects[1])
	for le: LineEdit in name_inputs[1]:
		out.append(le)
	out.append(random_button)
	if close_button != null and close_button.visible:
		out.append(close_button)
	out.append(deploy_button)
	return out


func _group_of(c: Control) -> String:
	return str(c.get_meta("group", ""))


func _is_card(c: Control) -> bool:
	return c is ChamferButton and c != deploy_button


## Moves the roving cursor to `idx` (wraps) and gives that control the Godot focus.
func set_focus_index(idx: int, scroll: bool = true) -> void:
	var items: Array[Control] = focus_items()
	focus_idx = posmod(idx, items.size())
	var el: Control = items[focus_idx]
	el.grab_focus()
	if scroll and _scroll != null:
		_scroll.ensure_control_visible(el)


func _activate(el: Control, dir: int = 1) -> void:
	UiUtil.sfx("tick")
	if el is ChamferButton:
		(el as ChamferButton).press()
	elif el is OptionButton:
		cycle_hat(el as OptionButton, dir)
	elif el is Button:
		(el as Button).pressed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	var vp: Viewport = get_viewport() # taken first: a key may change screen and remove this node
	if handle_key(key.keycode, key.shift_pressed, key.is_command_or_control_pressed(), key.echo) and vp != null:
		vp.set_input_as_handled()


## Applies one key press; returns true if the key was consumed. Exposed for tests.
func handle_key(keycode: Key, shift: bool, ctrl: bool, echo: bool = false) -> bool:
	var items: Array[Control] = focus_items()
	var cur: Control = items[clampi(focus_idx, 0, items.size() - 1)]
	var typing: bool = cur is LineEdit and (cur as LineEdit).has_focus()
	if keycode == KEY_ESCAPE:
		if echo:
			return true
		if typing:
			(cur as LineEdit).release_focus()
		else:
			back_to_menu()
		return true
	if keycode in [KEY_ENTER, KEY_KP_ENTER] and ctrl:
		deploy()
		return true
	if keycode == KEY_TAB:
		UiUtil.sfx("tick")
		set_focus_index(focus_idx + (-1 if shift else 1))
		return true
	if typing:
		if keycode in [KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]:
			UiUtil.sfx("tick")
			read_customization()
			set_focus_index(focus_idx + 1)
			return true
		if keycode == KEY_UP:
			UiUtil.sfx("tick")
			read_customization()
			set_focus_index(focus_idx - 1)
			return true
		return false
	match keycode:
		KEY_DOWN, KEY_S:
			UiUtil.sfx("tick")
			var g: String = _group_of(cur)
			if _is_card(cur):
				var i: int = focus_idx
				while i < items.size() - 1 and _group_of(items[i]) == g:
					i += 1
				set_focus_index(i)
			else:
				set_focus_index(focus_idx + 1)
			return true
		KEY_UP, KEY_W:
			UiUtil.sfx("tick")
			var g2: String = _group_of(cur)
			if _is_card(cur):
				var j: int = focus_idx
				while j > 0 and _group_of(items[j]) == g2:
					j -= 1
				set_focus_index(j)
			else:
				set_focus_index(focus_idx - 1)
			return true
		KEY_RIGHT, KEY_D:
			_step_horizontal(items, cur, 1)
			return true
		KEY_LEFT, KEY_A:
			_step_horizontal(items, cur, -1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not echo:
				_activate(cur, 1)
			return true
	return false


func _step_horizontal(items: Array[Control], cur: Control, dir: int) -> void:
	if cur is OptionButton:
		_activate(cur, dir)
		return
	UiUtil.sfx("tick")
	set_focus_index(focus_idx + dir)
	var nxt: Control = items[focus_idx]
	if _is_card(nxt):
		(nxt as ChamferButton).press()


# ---- building --------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	mode_cards.clear()
	diff_cards.clear()
	count_cards.clear()
	map_cards.clear()
	hat_selects.clear()
	name_inputs = [[], []]
	_squad_columns.clear()
	_theatre_images.clear()
	_face_buttons.clear()
	var real_vp: Vector2 = get_viewport_rect().size
	var vp: Vector2 = TouchMetrics.logical_size(real_vp) # the layout is built for this size, then scaled up
	_narrow = vp.x < NARROW_WIDTH
	_compact = UiUtil.is_compact(vp)

	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_backdrop.use_lobby_shade()
	_backdrop.set_map(GameState.map_idx)

	var whole: bool = _compact or _narrow or TouchMetrics.ui_scale(real_vp) > 1.0
	var side: float = 6.0 if whole else maxf(6.0, (real_vp.x - minf(1120.0, real_vp.x * 0.96)) * 0.5)
	var vert: float = 6.0 if whole else real_vp.y * 0.03
	var holder: Control = TouchMetrics.scaled_root(self, real_vp, Rect2(side, vert, real_vp.x - 2.0 * side, real_vp.y - 2.0 * vert))
	var frame := ChamferPanel.new()
	frame.cuts = Vector4(0, 18, 0, 18)
	frame.padding = Vector4(14, 8, 14, 8) if (_compact or _narrow) else Vector4(28, 24, 28, 24)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(frame)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.clip_contents = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14 if not _compact else 8)
	_scroll.add_child(body)

	body.add_child(_build_header())
	var top := GridContainer.new()
	top.columns = 1 if _narrow else 2
	top.add_theme_constant_override("h_separation", 16)
	top.add_theme_constant_override("v_separation", 12)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	top.add_child(_build_cards_section(tr("LOBBY_SEC_MODE"), MODE_CARDS, mode_cards, "mode", 3))
	top.add_child(_build_cards_section(tr("LOBBY_SEC_DIFF"), DIFF_CARDS, diff_cards, "diff", 3))
	var counts: Array[Array] = []
	for i in COUNT_KEYS.size():
		counts.append([str(i + 1), COUNT_KEYS[i][0], COUNT_KEYS[i][1]])
	body.add_child(_build_cards_section(tr("LOBBY_SEC_COUNT"), counts, count_cards, "count", 3 if _narrow else 6))
	body.add_child(_build_maps())
	body.add_child(_build_squads())
	body.add_child(_build_footer())

	_face_dialog = FileDialog.new()
	_face_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_face_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_face_dialog.use_native_dialog = true
	_face_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_face_dialog.file_selected.connect(_on_face_file)
	add_child(_face_dialog)

	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	_render_squad_rows()
	TouchMetrics.fit_taps(frame, real_vp, vp.y)
	_refresh_cards()
	# Cursor starts on the first mode card (index 1), as the original.
	focus_idx = 1
	set_focus_index(1, false)


func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	var h1: Label = UiUtil.spaced_label(tr("LOBBY_TITLE").to_upper(), "TitleBlackLabel", 16 if (_compact or _narrow) else 22, Palette.BRASS_BRIGHT, 2.0)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(h1)
	var sub: Label = UiUtil.label(tr("LOBBY_SUBTITLE"), "MutedLabel", 11)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(sub)
	var hint: Label = UiUtil.label(tr("LOBBY_KB_HINT"), "HintLabel", 10, Palette.BRASS)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	back_button = Button.new()
	back_button.theme_type_variation = "CmdButton"
	back_button.text = tr("LOBBY_BTN_BACK").to_upper()
	back_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_to_menu)
	back_button.focus_entered.connect(_on_item_focused.bind(back_button))
	head.add_child(back_button)
	return head


func _section_label(text: String) -> Label:
	return UiUtil.spaced_label(text.to_upper(), "SectionLabel", 11, Palette.BRASS, 1.4)


func _make_card(title: String, sub: String, group: String) -> ChamferButton:
	var card: ChamferButton = ChamferButton.make_card()
	if _compact:
		card.padding = Vector4(8, 5, 8, 5)
	card.set_meta("group", group)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Label = UiUtil.label(title.to_upper(), "BodyBoldLabel", 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var s: Label = UiUtil.label(sub, "MutedLabel", 10)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	box.add_child(s)
	card.add_child(box)
	card.set_meta("title_label", t)
	card.focus_entered.connect(_on_item_focused.bind(card))
	return card


func _build_cards_section(title: String, defs: Array[Array], into: Array[ChamferButton], group: String, columns: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_section_label(title))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	for def in defs:
		var card: ChamferButton = _make_card(tr(def[1]), tr(def[2]), group)
		var value: String = def[0]
		card.pressed.connect(_on_option_pressed.bind(group, value))
		grid.add_child(card)
		into.append(card)
	return col


func _on_option_pressed(group: String, value: String) -> void:
	match group:
		"mode":
			set_mode(value)
		"diff":
			set_difficulty(value)
		"count":
			set_count(int(value))
		"map":
			set_map(int(value))


func _on_item_focused(el: Control) -> void:
	var idx: int = focus_items().find(el)
	if idx >= 0:
		focus_idx = idx


func _build_maps() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_section_label(tr("LOBBY_SEC_MAP")))
	var grid := GridContainer.new()
	grid.columns = 2 if _narrow else 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var card_h: float = 88.0 if _compact else (104.0 if _narrow else 112.0)
	for idx in UiMaps.IDS.size():
		var card: ChamferButton = ChamferButton.make_theatre_card()
		card.set_meta("group", "map")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, card_h)
		var stack := Control.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.clip_contents = true
		card.add_child(stack)
		var pic := TextureRect.new()
		pic.texture = UiMaps.background(idx)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(pic)
		_theatre_images.append(pic)
		var shade := TextureRect.new()
		shade.texture = UiUtil.vertical_gradient(Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.15), Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.88))
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(shade)
		var texts := VBoxContainer.new()
		texts.set_anchors_preset(Control.PRESET_FULL_RECT)
		texts.offset_left = 10
		texts.offset_right = -10
		texts.offset_top = 7
		texts.offset_bottom = -8
		texts.add_theme_constant_override("separation", 1)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(texts)
		var badge: Label = UiUtil.label(tr(UiMaps.badge_key(idx)), "MonoHeavyLabel", 9, Palette.BRASS)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		texts.add_child(badge)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(spacer)
		var nm: Label = UiUtil.label(tr(UiMaps.name_key(idx)), "TitleLabel", 14, Color.WHITE)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge.clip_text = true
		texts.add_child(nm)
		if not _compact:
			var lm: Label = UiUtil.label(tr(UiMaps.sub_key(idx)), "MutedLabel", 10, Color(Palette.IVORY, 0.78))
			lm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lm.max_lines_visible = 2
			texts.add_child(lm)
		card.pressed.connect(_on_option_pressed.bind("map", str(idx)))
		card.focus_entered.connect(_on_item_focused.bind(card))
		card.mouse_entered.connect(_hover_map.bind(idx, true))
		card.mouse_exited.connect(_hover_map.bind(idx, false))
		grid.add_child(card)
		map_cards.append(card)
	return col


func _hover_map(idx: int, on: bool) -> void:
	if idx < _theatre_images.size():
		_theatre_images[idx].modulate = Color.WHITE if (on or idx == GameState.map_idx) else Color(0.84, 0.84, 0.84, 1)


func _build_squads() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_section_label(tr("LOBBY_SEC_SQUADS")))
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var titles: Array[String] = [tr("LOBBY_SQUAD_1"), tr("LOBBY_SQUAD_2")]
	for t in 2:
		var box := ChamferPanel.new()
		box.cuts = Vector4(0, 8, 0, 0)
		box.fill_top = Color(0, 0, 0, 0.34)
		box.fill_bottom = Color(0, 0, 0, 0.34)
		box.border_color = Color(1, 1, 1, 0.06)
		box.padding = Vector4(10, 8, 10, 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(box)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		box.add_child(inner)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		inner.add_child(head)
		var h3: Label = UiUtil.label(titles[t], "TitleLabel", 14, Palette.team_color(t))
		h3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(h3)
		var opt := OptionButton.new()
		opt.fit_to_longest_item = false
		opt.size_flags_horizontal = Control.SIZE_SHRINK_END
		opt.custom_minimum_size.x = 150 if _narrow else 190
		for hat: String in HAT_ORDER[t]:
			opt.add_item(tr(HAT_KEYS[hat]))
			opt.set_item_metadata(opt.item_count - 1, hat)
		_select_hat(opt, GameState.team_hats[t])
		opt.item_selected.connect(func(_i: int) -> void: read_customization())
		opt.focus_entered.connect(_on_item_focused.bind(opt))
		hat_selects.append(opt)
		head.add_child(opt)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		inner.add_child(rows)
		_squad_columns.append(rows)
	return col


## Rebuilds the name rows of both squads (JS renderLobbySquadInputs).
func _render_squad_rows() -> void:
	name_inputs = [[], []]
	_face_buttons.clear()
	var count: int = clampi(GameState.worms_per_team, 1, GameState.MAX_WORMS)
	var show_faces: bool = not OS.has_feature("web")
	for t in 2:
		var rows: VBoxContainer = _squad_columns[t]
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
		for i in count:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var idx: Label = UiUtil.label("0%d" % (i + 1), "MonoLabel", 10, Palette.IVORY_MUTED)
			idx.custom_minimum_size.x = 22
			row.add_child(idx)
			var le := LineEdit.new()
			le.max_length = 16
			le.text = GameState.team_names[t][i]
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.focus_entered.connect(_on_item_focused.bind(le))
			row.add_child(le)
			name_inputs[t].append(le)
			if show_faces:
				var fb := Button.new()
				fb.theme_type_variation = "CmdButton"
				fb.tooltip_text = tr("LOBBY_FACE_TOOLTIP")
				fb.focus_mode = Control.FOCUS_NONE
				fb.pressed.connect(_pick_face.bind(t, i))
				row.add_child(fb)
				_face_buttons[Vector2i(t, i)] = fb
				_update_face_button(t, i)
			rows.add_child(row)


func _update_face_button(t: int, i: int) -> void:
	var fb: Button = _face_buttons.get(Vector2i(t, i))
	if fb != null:
		fb.text = (tr("LOBBY_FACE_READY") if GameState.custom_faces[t][i] != null else tr("LOBBY_FACE_ADD")).to_upper()


func _pick_face(t: int, i: int) -> void:
	_face_target = Vector2i(t, i)
	_face_dialog.popup_centered_ratio(0.6)


func _on_face_file(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		return
	var biggest: int = maxi(img.get_width(), img.get_height())
	if biggest > 256:
		var k: float = 256.0 / float(biggest)
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	GameState.custom_faces[_face_target.x][_face_target.y] = img
	_update_face_button(_face_target.x, _face_target.y)


func _build_footer() -> Control:
	var foot := FlowContainer.new()
	foot.add_theme_constant_override("h_separation", 12)
	foot.add_theme_constant_override("v_separation", 8)
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_button = Button.new()
	random_button.theme_type_variation = "CmdButton"
	random_button.text = tr("LOBBY_BTN_RANDOM").to_upper()
	random_button.pressed.connect(_on_random_names)
	random_button.focus_entered.connect(_on_item_focused.bind(random_button))
	foot.add_child(random_button)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 20
	foot.add_child(spacer)
	# "Back to the current match" cannot resume a finished combat scene in the port: the button exists but stays hidden (deviation).
	close_button = Button.new()
	close_button.theme_type_variation = "CmdButton"
	close_button.text = tr("LOBBY_BTN_BACK_TO_GAME").to_upper()
	close_button.visible = false
	foot.add_child(close_button)
	deploy_button = ChamferButton.make_deploy()
	var dl: Label = UiUtil.spaced_label(tr("LOBBY_BTN_DEPLOY"), "TitleBlackLabel", 13, Color("#0b0d12"), 1.4)
	deploy_button.add_child(dl)
	deploy_button.pressed.connect(deploy)
	deploy_button.focus_entered.connect(_on_item_focused.bind(deploy_button))
	foot.add_child(deploy_button)
	return foot
