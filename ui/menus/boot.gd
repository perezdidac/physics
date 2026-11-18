## Boot screen: splash (kicker, title, subtitle) and the up/down main menu (quick match, 2 players, custom match).
## Keyboard: Up/Down or W/S move the cursor, Enter/Space activate. Mouse hover moves the cursor, click activates. Touch = tap.
extends Control

const MENU_KEYS: Array[Array] = [
	["MENU_QUICK_TITLE", "MENU_QUICK_SUB"],
	["MENU_2P_TITLE", "MENU_2P_SUB"],
	["MENU_CUSTOM_TITLE", "MENU_CUSTOM_SUB"],
]

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var cursor_idx: int = 0
var items: Array[ChamferButton] = []
var _arrows: Array[Label] = []
var _titles: Array[Label] = []
var _unlocked: bool = false


func _ready() -> void:
	theme = UiUtil.get_theme()
	_build()
	_set_cursor(0)
	get_viewport().size_changed.connect(_build)
	# Dev/test hook: CUCS_AUTOSTART=cpu starts a CPU-vs-CPU match at once; any other value starts a quick match.
	var auto: String = OS.get_environment("CUCS_AUTOSTART")
	if auto != "":
		GameState.prepare_quick_match("CPU_CPU" if auto == "cpu" else "1P_CPU")
		_go.call_deferred("combat")


## Moves the menu cursor (wraps) and refreshes the look.
func _set_cursor(idx: int) -> void:
	cursor_idx = posmod(idx, items.size())
	for i in items.size():
		var on: bool = i == cursor_idx
		items[i].active = on
		_arrows[i].modulate.a = 1.0 if on else 0.18
		_titles[i].add_theme_color_override("font_color", Palette.BRASS_BRIGHT if on else Palette.IVORY)
		var target: float = 28.0 if on else 22.0
		if not is_equal_approx(items[i].padding.x, target):
			var tw: Tween = items[i].create_tween() # dies with the item when the screen changes
			tw.tween_method(_shift_item.bind(items[i]), items[i].padding.x, target, 0.14)


func _shift_item(value: float, item: ChamferButton) -> void:
	if is_instance_valid(item):
		item.padding.x = value
		item.apply_padding()


## Runs menu entry `idx` (what a click or Enter does).
func activate(idx: int) -> void:
	match idx:
		0:
			UiUtil.sfx("title_fanfare")
			GameState.prepare_quick_match("1P_CPU")
			_go("combat")
		1:
			UiUtil.sfx("title_fanfare")
			GameState.prepare_quick_match("2P_LOCAL")
			_go("combat")
		2:
			UiUtil.sfx("tick")
			_go("lobby")


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true
	if not _unlocked and (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		_unlocked = true
		UiUtil.sound_call("unlock")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_UP, KEY_W:
			_set_cursor(cursor_idx - 1)
			get_viewport().set_input_as_handled()
		KEY_DOWN, KEY_S:
			_set_cursor(cursor_idx + 1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled() # before activate: it may change screen
			activate(cursor_idx)
		KEY_M:
			UiUtil.toggle_music()


func _build() -> void:
	for c in get_children():
		if c is RotateOverlay:
			continue
		c.queue_free()
	items.clear()
	_arrows.clear()
	_titles.clear()
	var vp: Vector2 = get_viewport_rect().size
	var compact: bool = UiUtil.is_compact(vp)
	var backdrop := MenuBackdrop.new()
	add_child(backdrop)
	backdrop.set_map(randi() % UiMaps.IDS.size())
	backdrop.use_splash_shade()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10 if compact else 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# Title block
	var head := VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 2 if compact else 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var kicker: Label = UiUtil.spaced_label(tr("SPLASH_KICKER").to_upper(), "TitleLabel", 12, Palette.KICKER_ORANGE, 4.5 if not compact else 2.5)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kicker.custom_minimum_size.x = minf(vp.x * 0.9, 760.0)
	kicker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(kicker)
	var title_size: int = 40 if compact else int(clampf(vp.x * 0.06, 40.0, 72.0))
	head.add_child(_make_title(tr("SPLASH_TITLE"), title_size))
	head.add_child(_make_subtitle(tr("SPLASH_SUBTITLE"), compact))

	# Menu
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6 if compact else 10)
	menu.custom_minimum_size.x = minf(440.0, vp.x * 0.92)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(menu)
	for i in MENU_KEYS.size():
		menu.add_child(_make_item(i, tr(MENU_KEYS[i][0]), tr(MENU_KEYS[i][1]), compact))

	var hint := RichTextLabel.new()
	hint.bbcode_enabled = true
	hint.fit_content = true
	hint.scroll_active = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("normal_font", get_theme_font("font", "HintLabel"))
	hint.add_theme_font_size_override("normal_font_size", 11)
	hint.add_theme_color_override("default_color", Palette.IVORY_HINT)
	hint.text = "[center]%s[/center]" % tr("MENU_HINT").replace("[b]", "[color=#f6cf77]").replace("[/b]", "[/color]")
	hint.custom_minimum_size.x = minf(vp.x * 0.92, 720.0)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(hint)
	_set_cursor(cursor_idx)
	if has_node("RotateOverlay"):
		move_child(get_node("RotateOverlay"), -1)


func _make_title(text: String, font_size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, font_size * 1.35)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow: Label = UiUtil.spaced_label(text, "TitleBlackLabel", font_size, Palette.TITLE_SHADOW, 4.0)
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shadow.position += Vector2(0, 5)
	holder.add_child(shadow)
	var title: Label = UiUtil.spaced_label(text, "TitleBlackLabel", font_size, Color.WHITE, 4.0)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/widgets/title_gradient.gdshader")
	mat.set_shader_parameter("text_height", font_size * 1.35)
	title.material = mat
	holder.add_child(title)
	return holder


func _make_subtitle(text: String, compact: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 26 if compact else 32)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = UiUtil.fade_gradient(Palette.FADE_DARK)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	for edge in 2:
		var line := TextureRect.new()
		line.texture = UiUtil.fade_gradient(Palette.BRASS_DIM)
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_SCALE
		line.anchor_right = 1.0
		line.anchor_top = float(edge)
		line.anchor_bottom = float(edge)
		line.offset_top = -1.0 if edge == 1 else 0.0
		line.offset_bottom = 0.0 if edge == 1 else 1.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(line)
	var l: Label = UiUtil.spaced_label(text, "TitleLabel", 14 if not compact else 12, Palette.IVORY, 5.0)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	return holder


func _make_item(idx: int, title: String, sub: String, compact: bool) -> ChamferButton:
	var item: ChamferButton = ChamferButton.make_menu_item()
	if compact:
		item.padding = Vector4(22, 7, 22, 7)
	item.name = "MenuItem%d" % idx
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow: Label = UiUtil.label("▶", "MonoHeavyLabel", 16, Palette.BRASS_BRIGHT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Label = UiUtil.spaced_label(title.to_upper(), "TitleLabel", 15, Palette.IVORY, 1.0)
	texts.add_child(t)
	var s: Label = UiUtil.label(sub, "MutedLabel", 11)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(s)
	row.add_child(texts)
	item.add_child(row)
	item.pressed.connect(func() -> void:
		_set_cursor(idx)
		activate(idx))
	item.hovered.connect(func() -> void: _set_cursor(idx))
	items.append(item)
	_arrows.append(arrow)
	_titles.append(t)
	return item
